process CHUNKBYZIP {
    tag "$meta.id"
    label 'process_single'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-script:${params.container_tag_name}"

    input:
    val(chunk_size)
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    tuple val("${task.process}"), val('chunkbyzip'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_chunkbyzip
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    chunk_by_zip.py \\
        --input_file $tsv \
        --chunk_size $chunk_size \
        --outdir ${prefix} \
        --file_list ${prefix}.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    mkdir -p ${prefix}
    touch ${prefix}.tsv
    """
}
