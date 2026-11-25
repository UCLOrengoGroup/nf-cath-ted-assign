process CHOPPDBZIP {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/24/24543d5cbb694fc2d7fdeef17c3ec6e892660085d0b48acca653a26337b507bc/data'
        : 'community.wave.seqera.io/library/python_pdb-tools:73f0210ed7bb8b99'}"

    input:

    tuple val(meta), path(consensus_chunk), path(zip)

    output:
    tuple val(meta), path("*_chopped_pdbs.tar.gz")    , emit: chopped_pdbs, optional: true
    tuple val(meta), path("*_empty_file_error.tar.gz"), emit: error_pdbs, optional: true
    tuple val("${task.process}"), val('python'),    eval("python --version | sed 's/Python //'"), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('pdb-tools'), eval("python -c 'import importlib.metadata as m; print(m.version(\"pdb-tools\"))'"), topic: versions, emit: versions_pdbtools


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    chop_pdbs.py \\
        $args \\
        --consensus $consensus_chunk \\
        --pdb-zip  $zip \\
        --output $prefix

    # Name the archive by whether any domain PDBs were written (find stops at the first match;
    # avoids 'tar -t | grep -q', which fails under pipefail when grep exits early)
    if [ -n "\$(find ${prefix} -name '*.pdb' -print -quit)" ]; then
        archive=${prefix}_chopped_pdbs.tar.gz
    else
        archive=${prefix}_empty_file_error.tar.gz
    fi

    tar \\
    --sort=name \\
    --mtime='UTC 1970-01-01' \\
    --owner=0 --group=0 --numeric-owner \\
    -czf \$archive \\
    -C ${prefix} .

    rm -rf ${prefix}
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo $args

    mkdir -p ${prefix}
    touch ${prefix}/stub_01.pdb
    tar -czf ${prefix}_chopped_pdbs.tar.gz -C ${prefix} .
    rm -rf ${prefix}
    """
}
