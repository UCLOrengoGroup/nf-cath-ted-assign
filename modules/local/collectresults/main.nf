process COLLECTRESULTS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/92/9200f9e1ca1e78c02f84374131c4216e0696a9cef6146a9b70cf4ee14e1baede/data'
        : 'community.wave.seqera.io/library/click_pandas_python:118f339c99551722'}"

    input:
    tuple val(meta), path(chainsaw)
    tuple val(meta2), path(merizo)
    tuple val(meta3), path(unidoc)

    output:
    tuple val(meta), path("*_domain_assignments.tsv"), emit: summary
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python3 -c "import pandas; print(pandas.__version__)"'), emit: versions_pandas, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    combine_results.py \\
        $args \\
        -m $merizo \\
        -u $unidoc \\
        -c $chainsaw \\
        -o ${prefix}_domain_assignments.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    touch ${prefix}_domain_assignments.tsv
    """
}
