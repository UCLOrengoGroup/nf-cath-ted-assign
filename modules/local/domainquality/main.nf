process DOMAINQUALITY {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-ted-tools:dev-arm64-latest"

    input:
    tuple val(meta), path(pdb_tar)

    output:
    tuple val(meta), path("*_domain_quality.csv"), emit: domainquality

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Cap math-library threads so domqual (PyTorch) doesn't oversubscribe shared CPU nodes
    export OMP_NUM_THREADS=${task.cpus}
    export MKL_NUM_THREADS=${task.cpus}
    export OPENBLAS_NUM_THREADS=${task.cpus}

    mkdir -p pdb
    tar -xzf ${pdb_tar} -C pdb

    . /app/ted-tools/ted_consensus_1.0/ted_consensus/bin/activate

    # Runs dom + domqual (resolved from /app/ted-tools/other-tools) on every chopped domain
    # stderr goes to a file so it can be checked below, then is copied to .command.err
    python3 /app/ted-tools/ted_consensus_1.0/scripts/run_domain_quality_checks.py \\
        -d pdb/ \\
        -o ${prefix}_domain_quality.unsorted.csv \\
        ${args} \\
        2> domain_quality.err
    cat domain_quality.err >&2

    # The script catches a failed (e.g. out-of-memory killed) domqual run, writes 0 for every
    # domain and exits 0. Fail the task instead; 137 lets errorStrategy retry with more memory.
    if grep -q "Error running domqual analysis" domain_quality.err; then
        echo "DomQual failed (likely out of memory), see .command.err" >&2
        exit 137
    fi

    perl -i.bak -pe 's/\\r\\n/\\n/g' ${prefix}_domain_quality.unsorted.csv

    head -n 1 ${prefix}_domain_quality.unsorted.csv > ${prefix}_domain_quality.csv
    tail -n +2 ${prefix}_domain_quality.unsorted.csv | sort -t, -k1,1 >> ${prefix}_domain_quality.csv
    rm -rf pdb
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}_domain_quality.csv
    """
}
