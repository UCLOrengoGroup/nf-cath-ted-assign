process STRIDE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/uclorengogroup/domain-annotation-pipeline-cath-af-cli:${params.container_tag_name}"

    input:
    tuple val(meta), path(pdb_tar)

    output:
    tuple val(meta), path("*_stride_batch.summary"), emit: summary
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("STRIDE module does not support Conda: STRIDE is not packaged on conda-forge/bioconda. Please use Docker, Singularity, Apptainer or Podman instead.")
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p pdb
    tar -xzf ${pdb_tar} -C pdb
    cd pdb

    for f in *.pdb; do
        stride \$f > "../\${f%.pdb}.stride" 2> "../\${f%.pdb}.stride.err" || {
        echo "STRIDE failed on \$f, see ../\${f%.pdb}.stride.err"
        continue
        }
    done
    cd ..

    create_stride_summary.py \\
        $args \\
        -d . \\
        -o ${prefix}_stride_batch.unsorted.summary \\
        --suffix .stride

    head -n 1 ${prefix}_stride_batch.unsorted.summary > ${prefix}_stride_batch.summary
    tail -n +2 ${prefix}_stride_batch.unsorted.summary | sort >> ${prefix}_stride_batch.summary

    find . -maxdepth 1 -name '*.stride.err' -size 0 -delete
    rm -rf pdb
    rm -f *.stride
    rm -f ${prefix}_stride_batch.unsorted.summary

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch ${prefix}_stride_batch.summary
    """
}
