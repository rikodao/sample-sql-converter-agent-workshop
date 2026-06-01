"""Summarize result/ directory into a Markdown report.

Usage:
    cd agent
    python -m utils.summarize_results [--result-dir ./result] [--output summary.md] [--object-list object_list.ini]

各オブジェクトの:
  - 種別 (object_list.ini から)
  - 変換結果 (BABELFISH_OK / OK / NG / INCOMPLETE)
  - テストケース数 + match level 内訳
  - 主な変換ルール / 失敗原因
を抽出して Markdown 集計レポートを生成する。
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ============================================================================
# Constants
# ============================================================================

VERDICT_BABELFISH_OK = "BABELFISH_OK"
VERDICT_OK = "OK (PG-native)"
VERDICT_NG = "NG"
VERDICT_INCOMPLETE = "INCOMPLETE"

VERDICT_EMOJI = {
    VERDICT_BABELFISH_OK: "🟢",
    VERDICT_OK: "🟡",
    VERDICT_NG: "🔴",
    VERDICT_INCOMPLETE: "⚪",
}


# ============================================================================
# Data classes
# ============================================================================


@dataclass
class ObjectResult:
    name: str
    object_type: str = "(unknown)"
    schema: str = "(unknown)"
    verdict: str = VERDICT_INCOMPLETE
    test_total: Optional[int] = None
    test_passed: Optional[int] = None
    match_exact: Optional[int] = None
    match_semantic: Optional[int] = None
    match_structural: Optional[int] = None
    target_engine: str = ""
    notes: list[str] = field(default_factory=list)
    files: list[str] = field(default_factory=list)
    babelfish_failure_reason: Optional[str] = None


# ============================================================================
# Helpers
# ============================================================================


def parse_object_list(path: Path) -> dict[str, tuple[str, str]]:
    """Parse object_list.ini → {short_name: (object_type, full_qualified_name)}.

    Returns mapping from result-dir-name (e.g. 'usp_xxx') to (type, full_name).
    """
    mapping: dict[str, tuple[str, str]] = {}
    if not path.exists():
        return mapping
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        obj_type, full_name = parts[0], parts[1]
        # short name (after last dot)
        short = full_name.split(".")[-1] if "." in full_name else full_name
        mapping[short] = (obj_type, full_name)
    return mapping


def first_int(text: str, pattern: str) -> Optional[int]:
    m = re.search(pattern, text)
    if m:
        try:
            return int(m.group(1))
        except (ValueError, IndexError):
            return None
    return None


def parse_test_summary(content: str) -> tuple[Optional[int], Optional[int], Optional[int], Optional[int], Optional[int]]:
    """Extract test totals from OK/BABELFISH_OK content text.

    Looks for patterns like:
      Test Cases: 13/13 matched
      Match Levels: EXACT=12, SEMANTIC=1, STRUCTURAL=0
    """
    total = passed = exact = semantic = structural = None

    m = re.search(r"Test\s+Cases\s*:\s*(\d+)\s*/\s*(\d+)", content)
    if m:
        passed = int(m.group(1))
        total = int(m.group(2))

    exact = first_int(content, r"EXACT\s*=\s*(\d+)")
    semantic = first_int(content, r"SEMANTIC\s*=\s*(\d+)")
    structural = first_int(content, r"STRUCTURAL\s*=\s*(\d+)")

    return total, passed, exact, semantic, structural


def parse_target_engine(content: str) -> str:
    m = re.search(r"Target\s+Engine\s*:\s*(.+?)$", content, flags=re.MULTILINE)
    if m:
        return m.group(1).strip()
    return ""


def collect_results(result_dir: Path, object_list_map: dict[str, tuple[str, str]]) -> list[ObjectResult]:
    results: list[ObjectResult] = []
    if not result_dir.exists():
        return results

    for sub in sorted(result_dir.iterdir()):
        if not sub.is_dir():
            continue
        name = sub.name
        files = sorted(p.name for p in sub.iterdir() if p.is_file())
        obj_type, full_name = object_list_map.get(name, ("(unknown)", name))
        schema = full_name.split(".")[0] if "." in full_name else "(unknown)"

        result = ObjectResult(
            name=name,
            object_type=obj_type,
            schema=schema,
            files=files,
        )

        # Verdict order: BABELFISH_OK > OK > NG > INCOMPLETE
        bf_path = sub / "BABELFISH_OK.txt"
        ok_path = sub / "OK.txt"
        ng_path = sub / "NG.txt"
        bf_attempt_path = sub / "babelfish_attempt.txt"

        # Parse Babelfish attempt for failure reason (even if it succeeded, may have
        # interesting notes)
        if bf_attempt_path.exists():
            attempt = bf_attempt_path.read_text(encoding="utf-8", errors="replace")
            m = re.search(r"RESULT\s*:\s*([A-Z_]+)", attempt)
            if m:
                result.babelfish_failure_reason = m.group(1)

        if bf_path.exists():
            content = bf_path.read_text(encoding="utf-8", errors="replace")
            result.verdict = VERDICT_BABELFISH_OK
            result.target_engine = parse_target_engine(content) or "Babelfish"
            t, p, e, s, st = parse_test_summary(content)
            result.test_total, result.test_passed = t, p
            result.match_exact, result.match_semantic, result.match_structural = e, s, st
        elif ok_path.exists():
            content = ok_path.read_text(encoding="utf-8", errors="replace")
            result.verdict = VERDICT_OK
            result.target_engine = parse_target_engine(content) or "PostgreSQL native"
            t, p, e, s, st = parse_test_summary(content)
            result.test_total, result.test_passed = t, p
            result.match_exact, result.match_semantic, result.match_structural = e, s, st
        elif ng_path.exists():
            content = ng_path.read_text(encoding="utf-8", errors="replace")
            result.verdict = VERDICT_NG
            m = re.search(r"NG\s+Reason\s*:\s*(.+?)$", content, flags=re.MULTILINE)
            if m:
                result.notes.append(f"NG Reason: {m.group(1).strip()}")
        else:
            result.verdict = VERDICT_INCOMPLETE

        results.append(result)
    return results


# ============================================================================
# Markdown rendering
# ============================================================================


def render_markdown(results: list[ObjectResult], result_dir: Path) -> str:
    if not results:
        return "# Migration Conversion Report\n\nNo results found.\n"

    total = len(results)
    by_verdict: Counter[str] = Counter(r.verdict for r in results)
    bf_ok = by_verdict.get(VERDICT_BABELFISH_OK, 0)
    pg_ok = by_verdict.get(VERDICT_OK, 0)
    ng = by_verdict.get(VERDICT_NG, 0)
    incomplete = by_verdict.get(VERDICT_INCOMPLETE, 0)
    success = bf_ok + pg_ok

    by_type: Counter[str] = Counter(r.object_type for r in results)

    babelfish_failures = Counter(
        r.babelfish_failure_reason for r in results if r.babelfish_failure_reason
    )

    # ----- Header -----
    lines: list[str] = []
    lines.append("# MSSQL → Aurora 移行: 集計レポート")
    lines.append("")
    lines.append(f"集計対象ディレクトリ: `{result_dir}`")
    lines.append("")

    # ----- Top-line metrics -----
    lines.append("## サマリー")
    lines.append("")
    lines.append("| 指標 | 値 |")
    lines.append("|---|---|")
    lines.append(f"| 全オブジェクト数 | {total} |")
    lines.append(f"| 🟢 Babelfish 互換 (BABELFISH_OK) | {bf_ok} ({_pct(bf_ok, total)}) |")
    lines.append(f"| 🟡 PG-native 移行 (OK) | {pg_ok} ({_pct(pg_ok, total)}) |")
    lines.append(f"| 🔴 失敗 (NG) | {ng} ({_pct(ng, total)}) |")
    lines.append(f"| ⚪ 未完了 (INCOMPLETE) | {incomplete} ({_pct(incomplete, total)}) |")
    lines.append(f"| **総合成功率** | **{_pct(success, total)}** |")
    lines.append("")

    # ----- Distribution bar -----
    lines.append("### 振り分けビジュアル")
    lines.append("")
    lines.append("```")
    lines.append(_ascii_bar("Babelfish", bf_ok, total))
    lines.append(_ascii_bar("PG-native", pg_ok, total))
    lines.append(_ascii_bar("NG       ", ng, total))
    if incomplete:
        lines.append(_ascii_bar("Incomp.  ", incomplete, total))
    lines.append("```")
    lines.append("")

    # ----- By object type -----
    lines.append("### オブジェクト種別")
    lines.append("")
    lines.append("| 種別 | 件数 |")
    lines.append("|---|---|")
    for t, c in sorted(by_type.items()):
        lines.append(f"| {t} | {c} |")
    lines.append("")

    # ----- Babelfish failure breakdown (if any) -----
    if babelfish_failures:
        lines.append("### Babelfish 失敗パターン (Stage 2 結果)")
        lines.append("")
        lines.append("| RESULT コード | 件数 |")
        lines.append("|---|---|")
        for reason, c in babelfish_failures.most_common():
            lines.append(f"| `{reason}` | {c} |")
        lines.append("")

    # ----- Per-object table -----
    lines.append("## オブジェクト別 結果")
    lines.append("")
    lines.append("| | オブジェクト | 種別 | 結果 | テスト | EXACT/SEMANTIC/STRUCTURAL | ターゲット |")
    lines.append("|---|---|---|---|---|---|---|")
    for r in results:
        emoji = VERDICT_EMOJI.get(r.verdict, "")
        test_str = (
            f"{r.test_passed}/{r.test_total}"
            if r.test_passed is not None and r.test_total is not None
            else "—"
        )
        match_str = (
            f"{r.match_exact}/{r.match_semantic}/{r.match_structural}"
            if r.match_exact is not None
            else "—"
        )
        target_short = (r.target_engine or "—").split("(")[0].strip()
        if len(target_short) > 30:
            target_short = target_short[:27] + "..."
        lines.append(
            f"| {emoji} | `{r.name}` | {r.object_type} | {r.verdict} | {test_str} | {match_str} | {target_short} |"
        )
    lines.append("")

    # ----- Test totals -----
    total_tests = sum(r.test_total for r in results if r.test_total)
    total_passed = sum(r.test_passed for r in results if r.test_passed)
    total_exact = sum(r.match_exact for r in results if r.match_exact)
    total_semantic = sum(r.match_semantic for r in results if r.match_semantic)
    total_structural = sum(r.match_structural for r in results if r.match_structural)

    if total_tests:
        lines.append("## テスト集計")
        lines.append("")
        lines.append(f"- 全テストケース数: **{total_tests}**")
        lines.append(f"- 通過数: **{total_passed}** ({_pct(total_passed, total_tests)})")
        lines.append(f"- EXACT match: {total_exact}")
        lines.append(f"- SEMANTIC match: {total_semantic}")
        lines.append(f"- STRUCTURAL match: {total_structural}")
        lines.append("")

    # ----- Failed objects detail -----
    failed = [r for r in results if r.verdict in (VERDICT_NG, VERDICT_INCOMPLETE)]
    if failed:
        lines.append("## 失敗 / 未完了オブジェクトの詳細")
        lines.append("")
        for r in failed:
            lines.append(f"### {VERDICT_EMOJI[r.verdict]} `{r.name}`")
            lines.append("")
            lines.append(f"- 結果: **{r.verdict}**")
            lines.append(f"- 種別: {r.object_type}")
            for note in r.notes:
                lines.append(f"- {note}")
            if r.files:
                lines.append(f"- 出力ファイル: {', '.join(r.files)}")
            lines.append("")

    # ----- Recommendations -----
    lines.append("## 推奨アクション")
    lines.append("")
    if bf_ok > 0:
        lines.append(
            f"- **{bf_ok} 件は Babelfish (TDS:1433) でそのまま動作可能** → アプリ改修最小、最短経路で移行可"
        )
    if pg_ok > 0:
        lines.append(
            f"- **{pg_ok} 件は Aurora PostgreSQL ネイティブ (PL/pgSQL) に変換済** → アプリ側 ConnectionString 修正、`postgres.sql` をデプロイ"
        )
    if ng > 0:
        lines.append(
            f"- **{ng} 件は NG**: 人手レビュー対象 (詳細は各 `NG.txt` を参照、CLR/Linked Server/Service Broker等は別途設計が必要)"
        )
    if incomplete > 0:
        lines.append(
            f"- **{incomplete} 件は INCOMPLETE**: パイプライン中断。`babelfish_attempt.txt` 等のログを確認し再実行"
        )
    lines.append("")

    # ----- Estimated migration effort -----
    lines.append("## 移行工数の目安 (参考値)")
    lines.append("")
    lines.append("| カテゴリ | 件数 | 1件あたり | 計 |")
    lines.append("|---|---|---|---|")
    lines.append(f"| Babelfish 即移行 | {bf_ok} | 0.25人日 | {bf_ok * 0.25:.2f}人日 |")
    lines.append(f"| PG-native + アプリ側調整 | {pg_ok} | 1.0人日 | {pg_ok * 1.0:.2f}人日 |")
    lines.append(f"| 失敗・人手対応 | {ng} | 3.0人日 | {ng * 3.0:.2f}人日 |")
    total_days = bf_ok * 0.25 + pg_ok * 1.0 + ng * 3.0
    lines.append(f"| **合計目安** | {total} | — | **{total_days:.2f}人日** |")
    lines.append("")
    lines.append(
        "> 注: 上記は**簡易な目安**であり、実際の工数はテーブル数・依存関係・アプリ側影響範囲に大きく左右されます。"
    )
    lines.append("")

    return "\n".join(lines)


def _pct(num: int, denom: int) -> str:
    if denom == 0:
        return "0%"
    return f"{num * 100 // denom}%"


def _ascii_bar(label: str, value: int, total: int, width: int = 40) -> str:
    if total == 0:
        return f"{label} | {value}"
    fill = int(value * width / total)
    bar = "█" * fill + "░" * (width - fill)
    return f"{label} | {bar} | {value:>3} ({_pct(value, total)})"


# ============================================================================
# CLI
# ============================================================================


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument(
        "--result-dir", default="./result", type=Path, help="結果ディレクトリ (default: ./result)"
    )
    parser.add_argument(
        "--object-list",
        default="./object_list.ini",
        type=Path,
        help="オブジェクトリスト (default: ./object_list.ini)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="出力Markdownファイル (default: stdout)",
    )
    args = parser.parse_args(argv)

    object_list_map = parse_object_list(args.object_list)
    # 補助: object_list_full.ini も併用
    full_list = args.object_list.parent / "object_list_full.ini"
    if full_list.exists():
        object_list_map.update(parse_object_list(full_list))

    results = collect_results(args.result_dir, object_list_map)
    md = render_markdown(results, args.result_dir)

    if args.output:
        Path(args.output).write_text(md, encoding="utf-8")
        print(f"Wrote {args.output} ({len(md)} chars, {len(results)} objects)", file=sys.stderr)
    else:
        sys.stdout.write(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
