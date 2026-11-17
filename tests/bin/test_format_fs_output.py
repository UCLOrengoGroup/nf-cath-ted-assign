"""Tests for bin/format_fs_output.py, run as a script the way the FOLDSEEK_PROCESSRESULTS module calls it."""

from pathlib import Path
import subprocess
import sys


SCRIPT = Path(__file__).parents[2] / "bin" / "format_fs_output.py"

# CathDomainList rows: domain, C, A, T, H, S, O, L, I, D, length, resolution
DOMAIN_LIST = (
    "1abcA01     1    10    10    10     1     1     1     1     1   100 1.500\n"
    "2defB02     3    40    50   300     2     1     1     1     1   120 2.000\n"
)


def m8_row(query, target, evalue, qlen=100, tlen=100, qtmscore=0.8, ttmscore=0.8, qcov=0.9, tcov=0.9):
    """Return one Foldseek row: query, target, fident, evalue, qlen, tlen, qtmscore, ttmscore, qcov, tcov."""

    return "\t".join(map(str, [query, target, 0.5, evalue, qlen, tlen, qtmscore, ttmscore, qcov, tcov])) + "\n"


def run_format(tmp_path, rows, check=True):
    m8 = tmp_path / "hits.m8"
    m8.write_text("".join(rows))
    domain_list = tmp_path / "CathDomainList"
    domain_list.write_text(DOMAIN_LIST)
    output = tmp_path / "parsed.tsv"
    result = subprocess.run(
        [sys.executable, SCRIPT, "--input", m8, "--cath", domain_list, "--output", output],
        check=check, capture_output=True, text=True,
    )
    return result, output


def parsed_rows(output):
    return [line.split("\t") for line in output.read_text().splitlines()]


def test_homologous_hit_gets_superfamily_code(tmp_path):
    _, output = run_format(tmp_path, [m8_row("q1", "1abcA01", evalue=0.001, qtmscore=0.7)])

    header, row = parsed_rows(output)
    assert header == ["query_id", "target_id", "evalue", "tmscore", "code", "type", "qcov", "tcov"]
    assert row[:6] == ["q1", "1abcA01", "0.001", "0.8", "1.10.10.10", "H"]


def test_topology_hit_gets_cat_code(tmp_path):
    # Too weak for H (E-value above 0.061144) but within the T thresholds
    _, output = run_format(tmp_path, [m8_row("q1", "2defB02", evalue=0.2, qtmscore=0.6, ttmscore=0.6)])

    assert parsed_rows(output)[1][4:6] == ["3.40.50", "T"]


def test_structural_hit_has_no_code(tmp_path):
    # TM-score above 0.513274 but E-value too high for H or T
    _, output = run_format(tmp_path, [m8_row("q1", "1abcA01", evalue=2.0, qtmscore=0.6, ttmscore=0.6)])

    assert parsed_rows(output)[1][4:6] == ["None", "N"]


def test_best_hit_prefers_homologous_over_topology(tmp_path):
    rows = [
        m8_row("q1", "2defB02", evalue=0.2, qtmscore=0.6, ttmscore=0.6),
        m8_row("q1", "1abcA01", evalue=0.01, qtmscore=0.7, ttmscore=0.7),
    ]
    _, output = run_format(tmp_path, rows)

    assert [row[:2] + row[4:6] for row in parsed_rows(output)[1:]] == [["q1", "1abcA01", "1.10.10.10", "H"]]


def test_query_without_qualifying_hit_is_omitted(tmp_path):
    _, output = run_format(tmp_path, [m8_row("q1", "1abcA01", evalue=2.0, qtmscore=0.3, ttmscore=0.3)])

    assert len(parsed_rows(output)) == 1


def test_header_is_written_without_hits(tmp_path):
    _, output = run_format(tmp_path, [])

    assert parsed_rows(output) == [["query_id", "target_id", "evalue", "tmscore", "code", "type", "qcov", "tcov"]]


def test_unknown_target_is_an_error(tmp_path):
    result, _ = run_format(tmp_path, [m8_row("q1", "9zzzZ99", evalue=0.001)], check=False)

    assert result.returncode != 0
    assert "failed to find target id 9zzzZ99" in result.stderr
