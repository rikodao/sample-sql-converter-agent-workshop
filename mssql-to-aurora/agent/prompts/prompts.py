"""Prompt loader for the 4-stage MSSQL → Aurora pipeline."""
import os

_module_dir = os.path.dirname(os.path.abspath(__file__))
_common_dir = os.path.join(_module_dir, "common")
_db_object_dir = os.path.join(_module_dir, "db_object")
_multi_agent_dir = os.path.join(_db_object_dir, "multi_agent")


def _load(dir_: str, filename: str) -> str:
    with open(os.path.join(dir_, filename), "rt", encoding="utf-8") as f:
        return f.read()


class MultiAgent:
    """4-stage prompt manager (MSSQL → Babelfish → PG-conv → PG-verify)."""

    def __init__(self) -> None:
        # 共通
        self.conversion_rules = _load(_common_dir, "conversion_rules_tsql.txt")
        self.test_strategy = _load(_db_object_dir, "test_strategy.txt")
        self.error_policy = _load(_db_object_dir, "error_policy.txt")
        self.output_specification = _load(_db_object_dir, "output_specification.txt")

        # 4 stages
        self.mssql = _load(_multi_agent_dir, "01_mssql_validation.txt")
        self.babelfish = _load(_multi_agent_dir, "02_babelfish_attempt.txt")
        self.conversion = _load(_multi_agent_dir, "03_postgres_conversion.txt")
        self.verification = _load(_multi_agent_dir, "04_postgres_verification.txt")

    def get_prompts(self) -> dict:
        return {
            "mssql": self.mssql.replace("{TEST_STRATEGY}", self.test_strategy),
            "babelfish": self.babelfish.replace(
                "{TEST_STRATEGY}", self.test_strategy
            ).replace("{ERROR_POLICY}", self.error_policy),
            "conversion": self.conversion.replace(
                "{CONVERSION_RULES}", self.conversion_rules
            ),
            "verification": self.verification.replace(
                "{OUTPUT_SPECIFICATION}", self.output_specification
            ).replace("{ERROR_POLICY}", self.error_policy),
        }
