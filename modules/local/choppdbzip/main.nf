process CHOPPDBZIP {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'quay.io/biocontainers/YOUR-TOOL-HERE' }"

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

    tar \\
    --sort=name \\
    --mtime='UTC 1970-01-01' \\
    --owner=0 --group=0 --numeric-owner \\
    -czf ${prefix}_chopped_pdbs.tar.gz \\
    -C ${prefix} .

    if ! tar -tzf ${prefix}_chopped_pdbs.tar.gz | grep -q '\\.pdb'; then
        mv ${prefix}_chopped_pdbs.tar.gz ${prefix}_empty_file_error.tar.gz
    fi

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
