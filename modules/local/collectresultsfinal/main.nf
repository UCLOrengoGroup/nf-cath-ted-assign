process COLLECTRESULTSFINAL {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/11/1139bd2a5ea970dad2b7e687125719f40aa777ab2cddee26d3caaa99ee1bb8d1/data'
        : 'community.wave.seqera.io/library/numpy_pandas_python:be349ee17c22ccbd'}"

    input:
    tuple val(meta), path(consensus)
    tuple val(meta2), path(globularity)
    tuple val(meta3), path(plddt)
    tuple val(meta4), path(domain_quality)
    tuple val(meta5), path(taxonomy)
    tuple val(meta6), path(foldseek)

    output:
    tuple val(meta), path("*_final_results.tsv"), emit: tsv

    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python3 -c "import pandas; print(pandas.__version__)"'), emit: versions_pandas, topic: versions
    tuple val("${task.process}"), val('numpy'), eval('python3 -c "import numpy; print(numpy.__version__)"'), emit: versions_numpy, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    combine_results_final.py \\
        $args \\
        -t $consensus \\
        -g $globularity \\
        -p $plddt \\
        -q $domain_quality \\
        -x $taxonomy \\
        -f $foldseek \\
        -o ${prefix}_final_results.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    touch ${prefix}_final_results.tsv
    """
}
