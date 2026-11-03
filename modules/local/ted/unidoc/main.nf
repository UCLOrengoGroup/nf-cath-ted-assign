process TED_UNIDOC {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-ted-tools:dev-arm64-latest"

    input:
    tuple val(meta), path(ids), path(zip)
    tuple val(meta2), path(merizo_chopping)

    output:
    tuple val(meta), path("*.chopping_unidoc.txt"), emit: unidoc
    tuple val(meta), path("*.chopping_unidoc.log"), emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    #-- Extract from zip into filtered_pdbs (batches of 200 to improve efficiency) --
    mkdir -p filtered_pdbs
    awk 'NF {print \$0 ".pdb"}' ${ids} > pdb_list.txt
    xargs -n 200 unzip -q ${zip} -d filtered_pdbs < pdb_list.txt

    # UniDoc processes structures in list order. The ids file is already sorted largest first
    # by input preparation.
    awk 'NF {print "filtered_pdbs/" \$0 ".pdb"}' ${ids} > structures.txt

    # Previous sorting, as in TED's segment.sh: count CA atoms in each structure, largest first
    # find filtered_pdbs -name '*.pdb' -exec awk '
    #     FNR == 1 { n[FILENAME] += 0 }
    #     \$1 == "ATOM" && substr(\$0, 13, 4) == " CA " { n[FILENAME]++ }
    #     END { for (f in n) print n[f] "\\t" f }
    # ' {} + \\
    #     | sort -k1,1nr \\
    #     | cut -f2 > structures.txt

    # ---------- UniDoc (re-segments the domains Merizo found) ----------
    unidoc \\
        $args \\
        -l structures.txt \\
        --inherit_chopping ${merizo_chopping} \\
        --out chopping_unidoc.raw.txt \\
        > ${prefix}.chopping_unidoc.log 2>&1

    if test ! -s chopping_unidoc.raw.txt; then
        echo "UniDoc segmentation produced no output. Check log at ${prefix}.chopping_unidoc.log" >&2
        exit 1
    fi

    # Remove small segments and single-residue domains, as in TED's segment.sh
    filter_domains.py \\
    chopping_unidoc.raw.txt \\
    -o chopping_unidoc.filtered.txt \\
    --offset_resi 0

    sort chopping_unidoc.filtered.txt > ${prefix}.chopping_unidoc.txt

    # ---------- Clean up filtered set ----------
    rm -rf filtered_pdbs
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}.chopping_unidoc.txt
    touch ${prefix}.chopping_unidoc.log
    """
}
