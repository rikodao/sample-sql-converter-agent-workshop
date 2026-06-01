"""
Helper shell utilities exposed via MCP.
"""
import os
from typing import Any


def mkdir_p(path: str) -> str:
    """Create directory and all parents (mkdir -p)."""
    os.makedirs(path, exist_ok=True)
    return f"created (or exists): {path}"
