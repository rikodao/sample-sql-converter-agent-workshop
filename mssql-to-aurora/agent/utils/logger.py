"""
Logger utility (simple wrapper).
既存 Oracle 側 utils/logger.py を踏襲。
"""
import logging
import sys


def setup_application_logging(log_level: int = logging.INFO) -> logging.Logger:
    root = logging.getLogger()
    root.setLevel(log_level)
    if not root.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter(
            "[%(asctime)s] [%(levelname)s] %(name)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)
        root.addHandler(handler)
    return root


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
