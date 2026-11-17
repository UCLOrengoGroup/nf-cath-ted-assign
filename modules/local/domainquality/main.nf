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
    python3 /app/ted-tools/ted_consensus_1.0/scripts/run_domain_quality_checks.py \\
        -d pdb/ \\
        -o ${prefix}_domain_quality.unsorted.csv \\
        ${args}

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
