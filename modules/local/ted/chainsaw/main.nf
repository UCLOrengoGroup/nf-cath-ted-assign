process TED_CHAINSAW {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-ted-tools:dev-arm64-latest"

    input:
    tuple val(meta), path(ids), path(zip)

    output:
    tuple val(meta), path("*.chopping_chainsaw.txt"), emit: chainsaw
    tuple val(meta), path("*.chopping_chainsaw.log"), emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Lever 1: cap math-library threads to the cores reserved for this task so PyTorch/BLAS
    # don't oversubscribe shared CPU nodes (near no-op on GPU nodes, where inference is on the GPU).
    export OMP_NUM_THREADS=${task.cpus}
    export MKL_NUM_THREADS=${task.cpus}
    export OPENBLAS_NUM_THREADS=${task.cpus}

    #-- Extract from zip into filtered_pdbs (batches of 200 to improve efficiency) --
    mkdir -p filtered_pdbs
    awk 'NF {print \$0 ".pdb"}' ${ids} > pdb_list.txt
    xargs -n 200 unzip -q ${zip} -d filtered_pdbs < pdb_list.txt

    # Previous sorting, as in TED's segment.sh: count CA atoms in each structure, largest first.
    # Not used by Chainsaw, which reads the folder (--structure_directory) and sorts by itself.
    # find filtered_pdbs -name '*.pdb' -exec awk '
    #     FNR == 1 { n[FILENAME] += 0 }
    #     \$1 == "ATOM" && substr(\$0, 13, 4) == " CA " { n[FILENAME]++ }
    #     END { for (f in n) print n[f] "\\t" f }
    # ' {} + \\
    #     | sort -k1,1nr \\
    #     | cut -f2 > structures.txt

    # ---------- Chainsaw (independent of Merizo/UniDoc) ----------
    # Chainsaw reads the whole folder and sorts the structures itself, largest first by default
    chainsaw \\
        $args \\
        --structure_directory filtered_pdbs \\
        --output chopping_chainsaw.raw.txt \\
        > ${prefix}.chopping_chainsaw.log 2>&1

    if test ! -s chopping_chainsaw.raw.txt; then
        echo "Chainsaw segmentation produced no output. Check log at ${prefix}.chopping_chainsaw.log" >&2
        exit 1
    fi

    # Remove small segments and single-residue domains, as in TED's segment.sh
    # (Chainsaw numbers residues from 0, the other tools from 1)
    filter_domains.py \\
    chopping_chainsaw.raw.txt \\
    -o chopping_chainsaw.filtered.txt \\
    --offset_resi 1

    sort chopping_chainsaw.filtered.txt > ${prefix}.chopping_chainsaw.txt

    # ---------- Clean up filtered set ----------
    rm -rf filtered_pdbs
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}.chopping_chainsaw.txt
    touch ${prefix}.chopping_chainsaw.log
    """
}
