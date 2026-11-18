process FOLDSEEK_PROCESSRESULTS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2f/2fbea5adf879d0edf5d4b72fa89fd2eddf57aae4226c8072981b464cd20acc27/data'
        : 'community.wave.seqera.io/library/click_python:3bbb4a35e95bc96b'}"

    input:
    tuple val(meta), path(aln)
    path(lookup_file)

    output:
    tuple val(meta), path("*_foldseek_parsed_results.tsv"), emit: summary
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('click'),  eval("python3 -c 'import importlib.metadata as m; print(m.version(\"click\"))'"), topic: versions, emit: versions_click

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    format_fs_output.py \\
        $args \\
        -i $aln \\
        -c $lookup_file \\
        -o ${prefix}_foldseek_parsed_results.unsorted.tsv

    head -n 1 ${prefix}_foldseek_parsed_results.unsorted.tsv > ${prefix}_foldseek_parsed_results.tsv
    tail -n +2 ${prefix}_foldseek_parsed_results.unsorted.tsv | sort >> ${prefix}_foldseek_parsed_results.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}_foldseek_parsed_results.tsv
    """
}
