process MEASUREGLOBULARITY {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-cath-af-cli:${params.container_tag_name}"

    input:
    tuple val(meta), path(pdb_tar)

    output:
    tuple val(meta), path("*_domain_globularity.tsv"), emit: globularity
    tuple val("${task.process}"), val('cath-alphaflow'), eval("python -c 'import importlib.metadata as m; print(m.version(\"cath-alphaflow\"))'"), topic: versions, emit: versions_cathalphaflow

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p pdb
    tar -xzf ${pdb_tar} -C pdb

    cath-af-cli \\
    $args \\
    measure-globularity \\
    --pdb_dir ./pdb \\
    --domain_globularity ${prefix}_domain_globularity_tmp.tsv

    dos2unix -n ${prefix}_domain_globularity_tmp.tsv ${prefix}_domain_globularity.unsorted.tsv || tr -d '\\r' < ${prefix}_domain_globularity_tmp.tsv > ${prefix}_domain_globularity.unsorted.tsv
    head -n 1 ${prefix}_domain_globularity.unsorted.tsv > ${prefix}_domain_globularity.tsv
    tail -n +2 ${prefix}_domain_globularity.unsorted.tsv | sort >> ${prefix}_domain_globularity.tsv
    rm -rf pdb
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}_domain_globularity.tsv
    """
}
