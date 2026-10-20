"""Tests for bin/create_input_from_zip_script.py, run as a script the way the CREATEINPUTZIP module calls it."""

from pathlib import Path
import subprocess
import sys
import zipfile


SCRIPT = Path(__file__).parents[2] / "bin" / "create_input_from_zip_script.py"


def test_lists_structure_files_with_their_zip(tmp_path):
    zip_dir = tmp_path / "zips"
    zip_dir.mkdir()
    with zipfile.ZipFile(zip_dir / "set1.zip", "w") as archive:
        archive.writestr("B.pdb", "")
        archive.writestr("A.cif", "")
        archive.writestr("notes.txt", "")
    (zip_dir / "not_a_zip.txt").write_text("")
    output = tmp_path / "input_mapping.tsv"

    subprocess.run(
        [sys.executable, SCRIPT, "--input_zip_dir", zip_dir, "--output", output],
        check=True, capture_output=True, text=True,
    )

    assert output.read_text().splitlines() == ["A\tset1.zip", "B\tset1.zip"]
