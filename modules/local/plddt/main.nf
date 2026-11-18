process PLDDT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a3/a3f1df1b7ac21563fc24563abb8de5df497c50e5b7bc186b1780cb0320c1af9d/data'
        : 'community.wave.seqera.io/library/python:3.13.16--0e261d9000df13f5'}"

    input:
    tuple val(meta), path(pdb_tar)

    output:
    tuple val(meta), path("*_domain_avg_plddt.tsv"), emit: plddt
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p pdb
    tar -xzf ${pdb_tar} -C pdb

    fetch_avg_plDDT.py \\
        $args \\
        ./pdb \\
        -o ${prefix}_domain_avg_plddt.unsorted.tsv

    sort -k1,1 ${prefix}_domain_avg_plddt.unsorted.tsv > ${prefix}_domain_avg_plddt.tsv
    rm -fr pdb
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}_domain_avg_plddt.tsv
    """
}
