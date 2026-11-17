# nf-cath-ted-assign

[![nf-test](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/actions/workflows/nf-test.yml/badge.svg)](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/actions/workflows/nf-test.yml)
[![Linting](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/actions/workflows/linting.yml/badge.svg)](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/actions/workflows/linting.yml)
[![Python tests](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/actions/workflows/python-tests.yml/badge.svg)](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/actions/workflows/python-tests.yml)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.4-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-4.2.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/4.2.1)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

> [!WARNING]
> **In development: this is not yet a working release.**
> The pipeline is still being built. Several steps are missing, and parameters and outputs may change without notice.
> Do not use it for production analyses yet. Until a first release, the working pipeline is [UCLOrengoGroup/domain-annotation-pipeline](https://github.com/UCLOrengoGroup/domain-annotation-pipeline).

## Introduction

**nf-cath-ted-assign** annotates protein structures with consensus domain boundaries and CATH superfamilies, following the approach of TED (The Encyclopedia of Domains).

It is a port of [UCLOrengoGroup/domain-annotation-pipeline](https://github.com/UCLOrengoGroup/domain-annotation-pipeline), built from the [nf-core](https://nf-co.re) template and following nf-core guidelines for modules, testing and linting. It is not an nf-core pipeline.

## Pipeline steps and status

| Step                              | What it does                                                                                                                                                                | Status      |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Input preparation                 | List the structures in each ZIP archive, split them into chunks, renumber experimental structures, keep single-chain proteins within a length range, fetch UniProt taxonomy | Available   |
| Domain segmentation and consensus | Chainsaw, Merizo and UniDoc, then a consensus of their domain boundaries ([#3](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/issues/3))                              | In progress |
| Domain quality checks             | STRIDE, globularity, domain quality, pLDDT ([#6](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/issues/6))                                                            | Planned     |
| CATH homology assignment          | Foldseek search against CATH, then contrasTED and Foldclass ([#7](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/issues/7))                                           | In progress |
| Final results                     | Combine domain boundaries, quality metrics, taxonomy and CATH assignments into one table                                                                                    | Planned     |

## Usage

> [!NOTE]
> If you are new to Nextflow, see [the Nextflow documentation](https://www.nextflow.io/docs/latest/install.html) for how to install it.

Prepare a samplesheet listing ZIP archives of PDB files, one archive per row:

```csv title="samplesheet.csv"
file_id,zip_file,structure_type
afdb_shard_1,/path/to/afdb_shard_1.zip,predicted
pdb_entries,/path/to/pdb_entries.zip,experimental
```

See the [usage documentation](docs/usage.md) for details of each column.

To try the parts that work so far on a small test dataset:

```bash
nextflow run UCLOrengoGroup/nf-cath-ted-assign \
   -r dev \
   -profile test,docker \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_.

## Pipeline output

See the [output documentation](docs/output.md) for the files the pipeline currently produces.

## Credits

nf-cath-ted-assign is led by Ian Sillitoe and Nick Edmunds, with support from Chris Wyatt and Fernando Duarte. It ports the domain-annotation-pipeline developed in the Orengo group at UCL.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

## Contributions and Support

If you would like to contribute, please see the [contributing guidelines](docs/CONTRIBUTING.md). For questions or problems, please open a [GitHub issue](https://github.com/UCLOrengoGroup/nf-cath-ted-assign/issues).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses the nf-core framework:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
