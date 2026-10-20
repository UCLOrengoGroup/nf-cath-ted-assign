"""Tests for bin/renumber_pdb.py, run as a script the way the RENUMBERPDB module calls it."""

import csv
from pathlib import Path
import subprocess
import sys
import zipfile

import gemmi


SCRIPT = Path(__file__).parents[2] / "bin" / "renumber_pdb.py"


def atom_line(serial, record, atom_name, residue_name, chain, residue_number, insertion_code=" "):
    """Return one fixed-width PDB ATOM or HETATM record."""

    return (
        f"{record:<6s}{serial:5d} {atom_name:^4s} {residue_name:>3s} {chain}{residue_number:4d}{insertion_code}   "
        "   0.000   0.000   0.000  1.00  0.00           C\n"
    )


def run_renumber(tmp_path, structures):
    """Zip the structures, renumber them and return the output paths."""

    pdb_zip = tmp_path / "input.zip"
    with zipfile.ZipFile(pdb_zip, "w") as archive:
        for pdb_id, text in structures.items():
            archive.writestr(f"{pdb_id}.pdb", text)
    ids = tmp_path / "ids.txt"
    ids.write_text("".join(f"{pdb_id}\n" for pdb_id in structures))
    outputs = {name: tmp_path / name for name in ("normalised.zip", "resmaps.zip", "errors.tsv")}
    subprocess.run(
        [
            sys.executable, SCRIPT,
            "--input_zip", pdb_zip,
            "--id_file", ids,
            "--normalised_zip", outputs["normalised.zip"],
            "--resmaps_zip", outputs["resmaps.zip"],
            "--error_file", outputs["errors.tsv"],
        ],
        check=True, capture_output=True, text=True,
    )
    return outputs


def test_renumbers_from_one_and_maps_back_to_original_numbering(tmp_path):
    pdb = "".join([
        atom_line(1, "ATOM", "CA", "ALA", "B", 10),
        atom_line(2, "ATOM", "CA", "GLY", "B", 10, "A"),
        atom_line(3, "ATOM", "CA", "SER", "B", 11),
        atom_line(4, "HETATM", "O", "HOH", "B", 101),
    ]) + "END\n"

    outputs = run_renumber(tmp_path, {"single": pdb})

    with zipfile.ZipFile(outputs["normalised.zip"]) as archive:
        model = gemmi.read_pdb_string(archive.read("single.pdb").decode())[0]
    assert [chain.name for chain in model] == ["A"]
    assert [(residue.seqid.num, residue.name) for residue in model[0]] == [(1, "ALA"), (2, "GLY"), (3, "SER")]

    with zipfile.ZipFile(outputs["resmaps.zip"]) as archive:
        resmap = list(csv.reader(archive.read("single_resmap.tsv").decode().splitlines(), delimiter="\t"))
    assert resmap[1:] == [
        ["single.pdb", "A", "1", "B", "10", ""],
        ["single.pdb", "A", "2", "B", "10", "A"],
        ["single.pdb", "A", "3", "B", "11", ""],
    ]


def test_reports_multi_chain_structures_by_file_name(tmp_path):
    pdb = atom_line(1, "ATOM", "CA", "ALA", "A", 1) + atom_line(2, "ATOM", "CA", "ALA", "B", 1) + "END\n"

    outputs = run_renumber(tmp_path, {"dimer": pdb})

    with zipfile.ZipFile(outputs["normalised.zip"]) as archive:
        assert archive.namelist() == []
    errors = list(csv.reader(outputs["errors.tsv"].read_text().splitlines(), delimiter="\t"))
    # The message names the PDB file, not the temporary path it was extracted to
    assert errors[1:] == [["dimer.pdb", "Expected one chain in dimer.pdb, found 2"]]
