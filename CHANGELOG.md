# nf-core/cathtedassign: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0dev - [unreleased<!-- TODO nf-core: replace with date on release -->]

Initial release of nf-core/cathtedassign, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- [#8](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/8), [#10](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/10), [#11](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/11) - Input preparation: list the structures in each input ZIP archive, split them into chunks, renumber experimental structures (`structure_type` samplesheet column), keep single-model, single-chain proteins within `--min_chain_residues`/`--max_chain_residues`, and fetch UniProt taxonomy for predicted structures
- [#13](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/13) - Length-aware second chunking for segmentation (`--heavy_chunk_size`), with the residue count of each chunk's longest structure (`max_residues`) in `meta`; ruff and pytest checks for the `bin/` scripts
- [#18](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/18) - `HOMCHECK` subworkflow: Foldseek search of chopped domains against a CATH database, with the best hit per domain classified as homologous superfamily, topology or structural match (not yet wired into the pipeline)

### `Fixed`

- [#20](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/20) - README states that the pipeline is in development and not an nf-core pipeline, and drops the nf-core branding

- [#12](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/12) - Run nf-test on GitHub-hosted runners; fix `nf-core pipelines lint` failures; remove `--debug` (use `--max_entries` on its own)

### `Dependencies`

- [#17](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/pull/17) - Update to the nf-core/tools 4.2.1 template (nf-schema 2.7.3, nft-utils 1.2.1)

### `Deprecated`
