"""Tests for bin/chunk_by_zip.py, run as a script the way the CHUNKBYZIP module calls it."""

from pathlib import Path
import subprocess
import sys

import pytest


SCRIPT = Path(__file__).parents[2] / "bin" / "chunk_by_zip.py"


def run_chunking(tmp_path, rows, chunk_size):
    """Write rows to a TSV, chunk them, and return [(chunk_id, ids, zip_name, max_residues), ...]."""

    input_file = tmp_path / "ids.tsv"
    input_file.write_text("".join("\t".join(map(str, row)) + "\n" for row in rows))
    subprocess.run(
        [
            sys.executable, SCRIPT,
            "--input_file", input_file,
            "--chunk_size", str(chunk_size),
            "--outdir", tmp_path / "chunks",
            "--file_list", tmp_path / "mapping.tsv",
        ],
        check=True, capture_output=True, text=True,
    )
    rows = [line.split("\t") for line in (tmp_path / "mapping.tsv").read_text().splitlines()[1:]]
    return [
        (int(chunk_id), Path(chunk_file).read_text().split(), zip_name, max_residues)
        for chunk_id, chunk_file, zip_name, max_residues in rows
    ]


def test_first_pass_sorts_ids_and_never_mixes_zips(tmp_path):
    rows = [("B2", "b.zip"), ("A1", "a.zip"), ("A3", "a.zip"), ("A2", "a.zip")]

    # Without residue counts, max_residues is left empty
    assert run_chunking(tmp_path, rows, 2) == [
        (0, ["A1", "A2"], "a.zip", ""),
        (1, ["A3"], "a.zip", ""),
        (2, ["B2"], "b.zip", ""),
    ]


def test_second_pass_chunks_by_length_and_records_longest_structure(tmp_path):
    rows = [("P1", "a.zip", 300), ("P2", "a.zip", 100), ("P3", "a.zip", 200), ("P4", "a.zip", 50)]

    # Chunks are filled shortest to longest; within a chunk the longest structure comes first,
    # and max_residues is the length of that longest structure
    assert run_chunking(tmp_path, rows, 2) == [
        (0, ["P2", "P4"], "a.zip", "100"),
        (1, ["P1", "P3"], "a.zip", "300"),
    ]


def test_rejects_rows_with_wrong_number_of_fields(tmp_path):
    with pytest.raises(subprocess.CalledProcessError) as error:
        run_chunking(tmp_path, [("only_one_field",)], 2)

    assert "Expected 2 or 3 tab-separated fields" in error.value.stderr
