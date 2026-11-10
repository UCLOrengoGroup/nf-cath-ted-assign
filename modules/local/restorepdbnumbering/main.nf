process RESTOREPDBNUMBERING {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/46/46924d668bf244397aff77dda82f0ff9470adc2c9396b20490e5f644688b322a/data'
        : 'community.wave.seqera.io/library/gemmi_python:dcda7813bb27249c'}"

    input:
    tuple val(meta), path(resmaps), path(pdb_tar)

    output:
    tuple val(meta), path("*_restored_chopped_pdbs.tar.gz"), emit: restored_chopped_pdbs
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('gemmi'), eval("python -c 'import gemmi; print(gemmi.__version__)'"), topic: versions, emit: versions_gemmi

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p restored_chopped_pdbs resmaps

    tar -xzf ${pdb_tar} -C restored_chopped_pdbs
    unzip -q ${resmaps} -d resmaps

    restore_pdb_numbering.py \\
        --pdb_dir restored_chopped_pdbs \\
        --resmap_dir resmaps
    
    tar \\
    --sort=name \\
    --mtime='UTC 1970-01-01' \\
    --owner=0 --group=0 --numeric-owner \\
    -czf ${prefix}_restored_chopped_pdbs.tar.gz \\
    -C restored_chopped_pdbs .
    
    rm -rf restored_chopped_pdbs resmaps
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p restored_chopped_pdbs
    touch restored_chopped_pdbs/stub_01.pdb
    tar -czf ${prefix}_restored_chopped_pdbs.tar.gz -C restored_chopped_pdbs .
    rm -rf restored_chopped_pdbs
    """
}
