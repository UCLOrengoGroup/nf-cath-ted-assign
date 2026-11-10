process CHUNKSMD5 {
    tag "$meta.id"
    label 'process_single'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
container "ghcr.io/uclorengogroup/domain-annotation-pipeline-cath-af-cli:${params.container_tag_name}" 

    input:
    tuple val(meta), path(pdb_tar)

    output:
    tuple val(meta), path("*_output.tsv"), emit: md5s
    tuple val("${task.process}"), val('cath-alphaflow'), eval("python -c 'import importlib.metadata as m; print(m.version(\"cath-alphaflow\"))'"), topic: versions, emit: versions_cathalphaflow

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p pdb
    tar -xzf $pdb_tar -C pdb

    cath-af-cli \\
    pdb-to-md5 \\
    -d ./pdb \\
    -o ${prefix}_output_tmp.tsv

    dos2unix \\
    -n ${prefix}_output_tmp.tsv ${prefix}_output.unsorted.tsv || tr -d '\\r' < ${prefix}_output_tmp.tsv > ${prefix}_output.unsorted.tsv
   
    head -n 1 ${prefix}_output.unsorted.tsv > ${prefix}_output.tsv
    tail -n +2 ${prefix}_output.unsorted.tsv | sort >> ${prefix}_output.tsv
    rm -rf pdb
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_output.tsv
    """
}
