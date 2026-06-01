# MSSQL → Aurora 移行: 集計レポート

集計対象ディレクトリ: `result`

## サマリー

| 指標 | 値 |
|---|---|
| 全オブジェクト数 | 21 |
| 🟢 Babelfish 互換 (BABELFISH_OK) | 12 (57%) |
| 🟡 PG-native 移行 (OK) | 8 (38%) |
| 🔴 失敗 (NG) | 1 (4%) |
| ⚪ 未完了 (INCOMPLETE) | 0 (0%) |
| **総合成功率** | **95%** |

### 振り分けビジュアル

```
Babelfish | ██████████████████████░░░░░░░░░░░░░░░░░░ |  12 (57%)
PG-native | ███████████████░░░░░░░░░░░░░░░░░░░░░░░░░ |   8 (38%)
NG        | █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ |   1 (4%)
```

### オブジェクト種別

| 種別 | 件数 |
|---|---|
| FUNCTION | 4 |
| PROCEDURE | 13 |
| TRIGGER | 2 |
| VIEW | 2 |

### Babelfish 失敗パターン (Stage 2 結果)

| RESULT コード | 件数 |
|---|---|
| `BABELFISH_OK` | 9 |
| `SYNTAX_FAILED` | 3 |
| `BABELFISH_COMPATIBLE` | 2 |
| `RUNTIME_ERROR` | 1 |
| `DEPENDENCY_MISSING` | 1 |
| `TEST_MISMATCH` | 1 |
| `RUNTIME_BLOCKED_OUTPUT_PARAMETER` | 1 |
| `DDL_NOT_AVAILABLE` | 1 |
| `RUNTIME_ERROR_SCHEMA_MISMATCH` | 1 |
| `SUCCESS` | 1 |

## オブジェクト別 結果

| | オブジェクト | 種別 | 結果 | テスト | EXACT/SEMANTIC/STRUCTURAL | ターゲット |
|---|---|---|---|---|---|---|
| 🟢 | `fn_format_employee_name` | FUNCTION | BABELFISH_OK | — | — | Babelfish |
| 🟡 | `fn_get_dept_summary` | FUNCTION | OK (PG-native) | 11/11 | 2/9/0 | PostgreSQL native |
| 🟢 | `fn_get_fiscal_year` | FUNCTION | BABELFISH_OK | — | — | Babelfish |
| 🟢 | `fn_split_csv` | FUNCTION | BABELFISH_OK | — | — | Babelfish |
| 🟢 | `trg_audit_employees` | TRIGGER | BABELFISH_OK | — | — | Babelfish |
| 🟡 | `trg_v_employee_full_update` | TRIGGER | OK (PG-native) | 12/12 | 7/5/0 | PostgreSQL native |
| 🟡 | `usp_archive_old_orders` | PROCEDURE | OK (PG-native) | 10/10 | 9/1/0 | PostgreSQL native |
| 🟢 | `usp_bulk_deactivate_employees` | PROCEDURE | BABELFISH_OK | — | — | Babelfish |
| 🟢 | `usp_calculate_employee_bonus` | PROCEDURE | BABELFISH_OK | — | — | Babelfish |
| 🟡 | `usp_dept_headcount_pivot` | PROCEDURE | OK (PG-native) | 10/10 | 9/1/0 | PostgreSQL native |
| 🟢 | `usp_dept_with_cumulative_metrics` | PROCEDURE | BABELFISH_OK | — | — | Babelfish |
| 🟢 | `usp_dynamic_count_with_output` | PROCEDURE | BABELFISH_OK | — | — | Babelfish |
| 🟡 | `usp_employee_json` | PROCEDURE | OK (PG-native) | 12/12 | 9/3/0 | PostgreSQL native |
| 🔴 | `usp_encrypted_demo` | PROCEDURE | NG | — | — | — |
| 🟢 | `usp_propagate_salary_raise` | PROCEDURE | BABELFISH_OK | — | — | Babelfish |
| 🟡 | `usp_recursive_org_chart` | PROCEDURE | OK (PG-native) | 11/11 | 10/1/0 | PostgreSQL native |
| 🟢 | `usp_search_employees_paged` | PROCEDURE | BABELFISH_OK | — | — | Babelfish |
| 🟡 | `usp_upsert_department` | PROCEDURE | OK (PG-native) | 12/12 | 10/2/0 | PostgreSQL native |
| 🟢 | `usp_validate_and_create_dept` | PROCEDURE | BABELFISH_OK | — | — | Babelfish |
| 🟡 | `v_active_employees` | VIEW | OK (PG-native) | 10/10 | 8/2/0 | PostgreSQL native |
| 🟢 | `v_employee_full` | VIEW | BABELFISH_OK | — | — | Babelfish |

## テスト集計

- 全テストケース数: **88**
- 通過数: **88** (100%)
- EXACT match: 64
- SEMANTIC match: 24
- STRUCTURAL match: 0

## 失敗 / 未完了オブジェクトの詳細

### 🔴 `usp_encrypted_demo`

- 結果: **NG**
- 種別: PROCEDURE
- NG Reason: PREREQUISITE_FAILED
- 出力ファイル: NG.txt, babelfish_attempt.txt, comparison_result.txt, mssql_unsupported.txt, postgres_test.sql, postgres_test.txt, postgres_unsupported.txt, prerequisites.txt, stage4_summary.txt

## 推奨アクション

- **12 件は Babelfish (TDS:1433) でそのまま動作可能** → アプリ改修最小、最短経路で移行可
- **8 件は Aurora PostgreSQL ネイティブ (PL/pgSQL) に変換済** → アプリ側 ConnectionString 修正、`postgres.sql` をデプロイ
- **1 件は NG**: 人手レビュー対象 (詳細は各 `NG.txt` を参照、CLR/Linked Server/Service Broker等は別途設計が必要)

## 移行工数の目安 (参考値)

| カテゴリ | 件数 | 1件あたり | 計 |
|---|---|---|---|
| Babelfish 即移行 | 12 | 0.25人日 | 3.00人日 |
| PG-native + アプリ側調整 | 8 | 1.0人日 | 8.00人日 |
| 失敗・人手対応 | 1 | 3.0人日 | 3.00人日 |
| **合計目安** | 21 | — | **14.00人日** |

> 注: 上記は**簡易な目安**であり、実際の工数はテーブル数・依存関係・アプリ側影響範囲に大きく左右されます。
