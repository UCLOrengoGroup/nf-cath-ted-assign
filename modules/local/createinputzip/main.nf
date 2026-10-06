process CREATEINPUTZIP {
    tag "$meta.id"
    label 'process_single'

    //conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-script:${params.container_tag_name}"
    //container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
    //    'quay.io/biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(zip)

    output:
    tuple val (meta), path("*.tsv"), emit: input_mapping
    tuple val("${task.process}"), val('createinput'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_createinput

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    create_input_from_zip_script.py \\
        --input_zip_dir . \
        --output ${prefix}_input_mapping.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    touch ${prefix}_input_mapping.tsv
    """
}
