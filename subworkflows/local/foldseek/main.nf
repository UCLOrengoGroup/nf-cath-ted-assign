include { FOLDSEEK_CREATEDB       } from '../../../modules/nf-core/foldseek/createdb/main'
include { FOLDSEEK_EASYSEARCH     } from '../../../modules/nf-core/foldseek/easysearch/main'
include { FOLDSEEK_PROCESSRESULTS } from '../../../modules/local/foldseek/processresults/main'

workflow FOLDSEEK {

    take:
    ch_chopped_pdbs // channel: [ val(meta), path(tar.gz) ]
    ch_target_db       // channel: [ val(meta), path(db_dir) ]
    ch_foldseek_lookup // channel: path(url)
    foldseek_chunks_per_batch

    main:

    // Prepare input for foldseek by grouping chopped PDBs into batches of size foldseek_chunks_per_batch (prob not necessary but copuing upstream)
    ch_chopped_pdbs
        .map { meta, tar ->
            def new_meta = [ id: meta.id, batch: meta.chunk_id.intdiv(foldseek_chunks_per_batch) ]
            [ new_meta, tar ]
        }
        .groupTuple()
        .set { ch_foldseek_input }

    //
    // MODULE: Run foldseek easysearch on each batch of chopped PDBs against the target database
    //
    FOLDSEEK_EASYSEARCH (
        ch_foldseek_input,
        ch_target_db
    )

    //
    // MODULE: Process foldseek results to generate a summary of hits with CATH superfamily assignments
    //
    FOLDSEEK_PROCESSRESULTS (
        FOLDSEEK_EASYSEARCH.out.aln,
        ch_foldseek_lookup
    )

    emit:
    results = FOLDSEEK_PROCESSRESULTS.out.summary // channel: [ val(meta), path(tsv) ], parsed hits with CATH superfamily
    aln     = FOLDSEEK_EASYSEARCH.out.aln         // channel: [ val(meta), path(m8) ], raw foldseek output

}
