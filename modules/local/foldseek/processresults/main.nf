process FOLDSEEK_PROCESSRESULTS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d9/d92165910ed32afaade41d724a643c106986e79d62122291d98375ec73e105d7/data'
        : 'community.wave.seqera.io/library/click_python:f480d4629ea44859'}"

    input:
    tuple val(meta), path(m8)
    path cath_domain_list

    output:
    tuple val(meta), path("${prefix}.foldseek_parsed_results.tsv"), emit: tsv
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('click'), eval("python3 -c 'import importlib.metadata as m; print(m.version(\"click\"))'"), emit: versions_click, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    format_fs_output.py \\
        ${args} \\
        --input ${m8} \\
        --cath ${cath_domain_list} \\
        --output ${prefix}.unsorted.tsv

    head -n 1 ${prefix}.unsorted.tsv > ${prefix}.foldseek_parsed_results.tsv
    tail -n +2 ${prefix}.unsorted.tsv | sort >> ${prefix}.foldseek_parsed_results.tsv
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.foldseek_parsed_results.tsv
    """
}
