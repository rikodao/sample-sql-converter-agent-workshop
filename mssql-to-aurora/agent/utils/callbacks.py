"""
Strands Agents callback handler.
ツール呼び出し・トークン使用量のロギング用。既存 Oracle 側 callbacks.py を踏襲。
"""
import time
from typing import Any

from utils.logger import get_logger

logger = get_logger("agent.callback")


class AgentCallbackHandler:
    def __init__(self, avoid_throttling: bool = False):
        self.avoid_throttling = avoid_throttling
        self.last_invocation_at = 0.0

    def __call__(self, **kwargs: Any) -> None:
        # Strands Agents コールバックでは event タイプに応じて kwargs が異なる
        event_type = kwargs.get("type", "unknown")
        if event_type == "tool_use":
            tool = kwargs.get("name", "?")
            logger.info(f"[tool_use] {tool}")
        elif event_type == "message":
            usage = kwargs.get("usage", {})
            if usage:
                logger.info(
                    f"[usage] input={usage.get('input_tokens')} output={usage.get('output_tokens')}"
                )
            if self.avoid_throttling:
                # 簡易的なクールダウン
                now = time.time()
                if now - self.last_invocation_at < 1.0:
                    time.sleep(1.0)
                self.last_invocation_at = now
