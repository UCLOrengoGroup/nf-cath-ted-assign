
process TRANSFORMCONSENSUS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a3/a3f1df1b7ac21563fc24563abb8de5df497c50e5b7bc186b1780cb0320c1af9d/data'
        : 'community.wave.seqera.io/library/python:3.13.16--0e261d9000df13f5'}"

    input:
    tuple val(meta), path(conensus_files)
    tuple val(meta2), path(md5_files)
    tuple val(meta3), path(stride_summaries)

    output:
    tuple val(meta), path("*_transformed_consensus.tsv"), emit: tsv
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    transform_consensus.py \\
        $args \\
        -i $conensus_files \\
        -m $md5_files \\
        -s $stride_summaries \\
        -o ${prefix}_transformed_consensus.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    touch ${prefix}_transformed_consensus.tsv
    """
}
