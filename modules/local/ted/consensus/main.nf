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
    tuple val(meta), path('output/consensus_sorted.tsv'), emit: consensus
    tuple val(meta), path('output/consensus.tsv.changed.txt'), emit: consensus_changed

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    . /app/ted-tools/ted_consensus_1.0/ted_consensus/bin/activate
    mkdir -p output

    # Calculate consensus from Merizo, Chainsaw and UniDoc choppings
    python3 /app/ted-tools/ted_consensus_1.0/scripts/get_consensus.py -c ${merizo} ${chainsaw} ${unidoc} -o output/consensus.tsv > output/consensus.log 2>&1
    if test ! -f output/consensus.tsv; then
        echo "Consensus calculation failed. Check log at output/consensus.log"
        exit 1
    fi

    # Filter consensus domains (also writes output/consensus.tsv.changed.txt)
    python3 /app/ted-tools/ted_consensus_1.0/scripts/filter_domains_consensus.py output/consensus.tsv -o output/consensus.tsv.tmp
    mv output/consensus.tsv.tmp output/consensus.tsv

    sort output/consensus.tsv > output/consensus_sorted.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    mkdir output
    touch output/consensus_sorted.tsv
    touch output/consensus.tsv.changed.txt
    """
}
