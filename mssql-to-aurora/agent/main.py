"""CLI entry point for MSSQL → Aurora PostgreSQL / Babelfish agent.

Usage:
    uv run main.py --multi-agent --prompt "PROCEDURE dbo.usp_xxx"
    uv run main.py --multi-agent --prompt "..." --avoid-throttling
    uv run main.py --multi-agent --prompt "..." --always-validate-both
"""
import argparse
import gc
import json
import logging
import os
from pathlib import Path
from time import sleep

from botocore.config import Config
from mcp import StdioServerParameters
from mcp.client.stdio import stdio_client
from strands import Agent
from strands.models import BedrockModel
from strands.tools.mcp import MCPClient
from strands_tools import file_read, file_write
from utils.callbacks import AgentCallbackHandler
from utils.logger import setup_application_logging

logger = setup_application_logging(log_level=logging.INFO)
os.environ["BYPASS_TOOL_CONSENT"] = "true"


def load_mcp_config():
    with open("mcp.json", "r") as f:
        return json.load(f)


def create_bedrock_model() -> BedrockModel:
    return BedrockModel(
        model_id="global.anthropic.claude-sonnet-4-5-20250929-v1:0",
        region_name="us-east-1",
        temperature=0,
        cache_tools="default",
        additional_request_fields={"anthropic_beta": ["context-1m-2025-08-07"]},
        boto_client_config=Config(
            retries={"total_max_attempts": 5, "mode": "standard"},
            connect_timeout=10,
            read_timeout=600,
        ),
    )


def create_mcp_client() -> MCPClient:
    config = load_mcp_config()
    server_config = config["mcpServers"]["mssql-to-aurora"]

    # MCP サーバは子プロセスで起動されるため、現プロセスの DB 接続関連 env を伝播させる。
    # mcp.json の env フィールドはそのまま使い、_必要な_ ホスト・シークレット名・リージョンを注入。
    env = dict(server_config.get("env", {}))
    for key in (
        "MSSQL_HOST",
        "MSSQL_SECRET_NAME",
        "MSSQL_PORT",
        "MSSQL_DRIVER",
        "MSSQL_DATABASE",
        "BABELFISH_HOST",
        "BABELFISH_SECRET_NAME",
        "BABELFISH_DB",
        "BABELFISH_TDS_PORT",
        "BABELFISH_PG_PORT",
        "BABELFISH_TDS_DRIVER",
        "AURORA_PG_SECRET_NAME",
        "AURORA_PG_DBNAME",
        "AWS_REGION",
        "AWS_DEFAULT_REGION",
    ):
        if key in os.environ and key not in env:
            env[key] = os.environ[key]
    # AWS 認証情報も伝播（IAMロールベースなので不要なケースが多いが念のため）
    for key in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN", "AWS_PROFILE"):
        if key in os.environ and key not in env:
            env[key] = os.environ[key]

    return MCPClient(
        lambda: stdio_client(
            StdioServerParameters(
                command=server_config["command"],
                args=server_config["args"],
                env=env,
            )
        )
    )


def resumable_agent_run(
    mcp_client: MCPClient, agent: Agent, prompt: str, max_retry: int = 1000
) -> Agent:
    """Bedrock スロットリング時の再試行付き実行 (Oracle 側と同じロジック)."""
    last_user_content = prompt
    with mcp_client:
        for i in range(max_retry):
            try:
                agent(last_user_content)
                break
            except Exception as e:
                logger.error(f"Error (try {i + 1}/{max_retry}): {e}")
                if not agent.messages:
                    last_user_content = prompt
                    gc.collect()
                    sleep(60)
                    continue
                for _ in range(2):
                    if not agent.messages:
                        break
                    if agent.messages[-1].get("role") == "assistant":
                        del agent.messages[-1]
                    elif agent.messages[-1].get("role") == "user":
                        last_user_content = agent.messages.pop().get("content", prompt)
                        break
                    else:
                        raise e
                gc.collect()
                sleep(60)
    return agent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", type=str, help="Prompt text (object spec)")
    parser.add_argument(
        "--multi-agent",
        action="store_true",
        help="Enable 4-stage MSSQL → Babelfish → PG-native pipeline",
    )
    parser.add_argument(
        "--avoid-throttling",
        action="store_true",
        help="Enable Bedrock throttling-aware retry/cooldown",
    )
    parser.add_argument(
        "--always-validate-both",
        action="store_true",
        help="Run PG conversion+verification even if Babelfish succeeded",
    )
    args = parser.parse_args()

    logger.info("MSSQL → Aurora conversion start")

    if not args.multi_agent:
        # 簡易: マルチエージェント前提とする (Oracle側と挙動を統一)
        logger.error("--multi-agent is required for this pipeline.")
        return

    if not args.prompt:
        logger.error("--prompt is required")
        return

    from multi_agent_processor import run_multi_agent_conversion

    mcp_client = create_mcp_client()

    def create_agent_with_prompt(system_prompt: str) -> Agent:
        with mcp_client:
            mcp_tools = mcp_client.list_tools_sync()
            all_tools = [file_read, file_write] + mcp_tools
        return Agent(
            system_prompt=system_prompt,
            tools=all_tools,
            callback_handler=AgentCallbackHandler(avoid_throttling=args.avoid_throttling),
            model=create_bedrock_model(),
        )

    run_multi_agent_conversion(
        object_spec=args.prompt,
        create_agent_func=create_agent_with_prompt,
        mcp_client=mcp_client,
        avoid_throttling=args.avoid_throttling,
        early_exit_on_babelfish=not args.always_validate_both,
        resumable_agent_run_func=resumable_agent_run if args.avoid_throttling else None,
    )

    logger.info("MSSQL → Aurora conversion complete")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logger.critical("Application failed", exc_info=True)
