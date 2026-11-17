process TED_CHAINSAW {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-ted-tools:dev-arm64-latest"

    input:
    tuple val(meta), path(ids), path(zip)

    output:
    tuple val(meta), path("*/chopping_chainsaw_sorted.txt"), emit: chainsaw
    tuple val(meta), path("*/chopping_chainsaw.log"), emit: log

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
    xargs -a pdb_list.txt -n 200 unzip -q ${zip} -d filtered_pdbs

    # ---------- Set up segmentation environment ----------
    cp /app/ted-tools/ted_consensus_1.0/run_segmentation.sh .
    ln -s /app/ted-tools/ted_consensus_1.0/ted_consensus .
    cp -a /app/ted-tools/ted_consensus_1.0/scripts ./scripts
    mkdir -p ./programs
    ln -s /app/ted-tools/ted_consensus_1.0/programs/merizo ./programs/merizo
    ln -s /app/ted-tools/ted_consensus_1.0/programs/chainsaw ./programs/chainsaw
    mkdir -p ./programs/unidoc
    cp /app/ted-tools/ted_consensus_1.0/programs/unidoc/Run_UniDoc_from_scratch_structure_afdb.py ./programs/unidoc/
    mkdir -p ./programs/unidoc/bin
    cp /app/ted-tools/ted_consensus_1.0/programs/unidoc/bin/UniDoc_struct ./programs/unidoc/bin/UniDoc_struct
    cp /app/ted-tools/ted_consensus_1.0/programs/unidoc/bin/stride ./programs/unidoc/bin/stride
    . ted_consensus/bin/activate
    mkdir -p output

    # ---------- Chainsaw (independent of Merizo/UniDoc) ----------
    bash scripts/segment.sh -i ./filtered_pdbs -m chainsaw -o ./output > output/chopping_chainsaw.log 2>&1
    if test ! -s output/chopping_chainsaw.txt; then
        echo "Chainsaw segmentation failed. Check log at output/chopping_chainsaw.log"
        exit 1
    fi

    sort output/chopping_chainsaw.txt > output/chopping_chainsaw_sorted.txt

    # ---------- Clean up filtered set ----------
    rm -rf filtered_pdbs
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args
    
    mkdir output
    touch output/chopping_chainsaw_sorted.txt
    touch output/chopping_chainsaw.log
    """
}
