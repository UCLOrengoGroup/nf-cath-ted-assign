process STRIDE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a3/a3f1df1b7ac21563fc24563abb8de5df497c50e5b7bc186b1780cb0320c1af9d/data'
        : 'community.wave.seqera.io/library/python:3.13.16--0e261d9000df13f5'}"

    input:
    tuple val(meta), path(pdb_tar)

    output:
    tuple val(meta), path("*_stride_batch.summary"), emit: summary
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
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

    create_stride.py \\
        $args \\
        -d . \\
        -o ${prefix}_stride_batch.summary \\
        suffix .stride \\
    
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
