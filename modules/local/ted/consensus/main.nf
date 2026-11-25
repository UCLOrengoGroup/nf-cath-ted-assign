process TED_CONSENSUS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/34/34703bf9755ba2d792c768ab6040fe547b6c6e954310486f2e423b8eba61bbe7/data'
:         'community.wave.seqera.io/library/ted-consensus:0.1.8-0--56c5b76ab544f0cc' }"

    input:
    tuple val(meta), path(chainsaw)
    tuple val(meta2), path(merizo)
    tuple val(meta3), path(unidoc)

    output:
    tuple val(meta), path("*_consensus_sorted.tsv"), emit: consensus
    tuple val(meta), path("*_consensus.tsv.changed.txt"), emit: consensus_changed

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Calculate consensus from Merizo, Chainsaw and UniDoc choppings
    ted-consensus \\
        $args \\
        -c ${merizo} ${chainsaw} ${unidoc} \\
        -o ${prefix}_consensus.tsv \\
        > ${prefix}_consensus.log 2>&1

    if test ! -f ${prefix}_consensus.tsv; then
        echo "Consensus calculation failed. Check log at ${prefix}_consensus.log" >&2
        exit 1
    fi

    # Filter consensus domains (also writes ${prefix}_consensus.tsv.changed.txt)
    filter_domains_consensus.py \\
        ${prefix}_consensus.tsv \\
        -o ${prefix}_consensus.tsv.tmp \\
        --changed_file ${prefix}_consensus.tsv.changed.txt

    mv ${prefix}_consensus.tsv.tmp ${prefix}_consensus.tsv

    sort ${prefix}_consensus.tsv > ${prefix}_consensus_sorted.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}_consensus_sorted.tsv
    touch ${prefix}_consensus.tsv.changed.txt
    """
}
