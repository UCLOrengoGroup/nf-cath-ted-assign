process TED_CONSENSUS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-ted-tools:dev-arm64-latest"

    input:
    tuple val(meta), path(chainsaw)
    tuple val(meta2), path(merizo)
    tuple val(meta3), path(unidoc)

    output:
    tuple val(meta), path('*.consensus_sorted.tsv'), emit: consensus
    tuple val(meta), path('*.consensus.tsv.changed.txt'), emit: consensus_changed

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
    -o ${prefix}.consensus.tsv \\
    > ${prefix}.consensus.log 2>&1

    if test ! -f ${prefix}.consensus.tsv; then
        echo "Consensus calculation failed. Check log at ${prefix}.consensus.log"
        exit 1
    fi

    # Filter consensus domains (also writes output/consensus.tsv.changed.txt)
    filter_domains_consensus.py \\
    ${prefix}.consensus.tsv \\
    -o ${prefix}.consensus.tsv.tmp

    mv ${prefix}.consensus.tsv.tmp ${prefix}.consensus.tsv

    sort ${prefix}.consensus.tsv > ${prefix}.consensus_sorted.tsv

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    touch ${prefix}.consensus_sorted.tsv
    touch ${prefix}.consensus.tsv.changed.txt
    """
}
