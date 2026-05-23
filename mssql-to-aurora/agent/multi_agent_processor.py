"""4-stage multi-agent processor:

  Stage 1: MSSQL検証      - 対象オブジェクトの DDL 取得・テスト作成・実行
  Stage 2: Babelfish試行  - mssql.sql を TDS:1433 へそのまま投入し、結果比較
                            成功なら BABELFISH_OK.txt → 早期終了可
  Stage 3: PG変換         - T-SQL → PL/pgSQL 変換（PGネイティブ向け）
  Stage 4: PG検証         - 変換結果のテスト実行・比較・OK/NG 判定

設計詳細: docs/04-conversion-strategy.md / docs/adr/0003-multi-agent-pipeline.md
"""
import os
from typing import Callable, Optional

from prompts.prompts import MultiAgent
from utils.logger import get_logger

logger = get_logger("multi_agent")


def get_result_dir(object_spec: str, base_dir: str = "./result") -> str:
    """オブジェクト指定 (例: 'PROCEDURE dbo.usp_xxx') から結果ディレクトリを決定."""
    parts = object_spec.strip().split()
    if len(parts) >= 2:
        full_name = parts[1]
        if "." in full_name:
            name_parts = full_name.split(".")
            result_dir_name = (
                ".".join(name_parts[1:]) if len(name_parts) >= 2 else name_parts[-1]
            )
        else:
            result_dir_name = full_name
    else:
        result_dir_name = object_spec.strip()
    return os.path.join(base_dir, result_dir_name)


def _has_file(path: str) -> bool:
    return os.path.isfile(path) and os.path.getsize(path) > 0


def run_multi_agent_conversion(
    object_spec: str,
    create_agent_func: Callable,
    mcp_client,
    avoid_throttling: bool = False,
    early_exit_on_babelfish: bool = True,
    resumable_agent_run_func: Optional[Callable] = None,
) -> None:
    prompts = MultiAgent().get_prompts()
    result_dir = get_result_dir(object_spec)
    os.makedirs(result_dir, exist_ok=True)

    babelfish_ok_path = os.path.join(result_dir, "BABELFISH_OK.txt")

    # 各ステージのメッセージテンプレート
    msg_mssql = f"対象オブジェクト: {object_spec}\n結果保存先: {result_dir}/"
    msg_babelfish = (
        f"対象オブジェクト: {object_spec}\n"
        f"MSSQL DDL: {result_dir}/mssql.sql\n"
        f"MSSQL テスト結果: {result_dir}/mssql_test.txt\n"
        f"結果保存先: {result_dir}/"
    )
    msg_conversion = (
        f"対象オブジェクト: {object_spec}\n"
        f"MSSQL DDL: {result_dir}/mssql.sql\n"
        f"結果保存先: {result_dir}/"
    )
    msg_verification = (
        f"対象オブジェクト: {object_spec}\n"
        f"MSSQL テスト結果: {result_dir}/mssql_test.sql, {result_dir}/mssql_test.txt\n"
        f"PostgreSQL 変換結果: {result_dir}/postgres.sql\n"
        f"結果保存先: {result_dir}/"
    )

    def run_agent(agent, message):
        if avoid_throttling and resumable_agent_run_func:
            resumable_agent_run_func(mcp_client, agent, message)
        else:
            with mcp_client:
                agent(message)

    # Stage 1: MSSQL検証
    logger.info(f"[Stage 1/4] MSSQL検証 開始: {object_spec}")
    mssql_agent = create_agent_func(prompts["mssql"])
    run_agent(mssql_agent, msg_mssql)
    logger.info(f"[Stage 1/4] MSSQL検証 完了: {object_spec}")

    # Stage 2: Babelfish試行
    logger.info(f"[Stage 2/4] Babelfish試行 開始: {object_spec}")
    babelfish_agent = create_agent_func(prompts["babelfish"])
    run_agent(babelfish_agent, msg_babelfish)
    logger.info(f"[Stage 2/4] Babelfish試行 完了: {object_spec}")

    # 早期終了判定
    if early_exit_on_babelfish and _has_file(babelfish_ok_path):
        logger.info(
            f"[Stage 2/4] Babelfish 成功 → Stage 3/4 をスキップ（--always-validate-both で両方検証可）"
        )
        return

    # Stage 3: PG変換
    logger.info(f"[Stage 3/4] PG変換 開始: {object_spec}")
    conv_agent = create_agent_func(prompts["conversion"])
    run_agent(conv_agent, msg_conversion)
    logger.info(f"[Stage 3/4] PG変換 完了: {object_spec}")

    # Stage 4: PG検証
    logger.info(f"[Stage 4/4] PG検証 開始: {object_spec}")
    verif_agent = create_agent_func(prompts["verification"])
    run_agent(verif_agent, msg_verification)
    logger.info(f"[Stage 4/4] PG検証 完了: {object_spec}")

    logger.info(f"4-stage 完了: {object_spec} → {result_dir}")
