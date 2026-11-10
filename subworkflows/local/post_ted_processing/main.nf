include { CHOPPDBZIP    } from '../../../modules/local/choppdbzip/main'
include { CHUNKSMD5     } from '../../../modules/local/chunksmd5/main'

workflow POST_TED_PROCESSING {

    take:
    ch_consensus  // channel: [ val(meta), path(consensus) ]
    ch_structures // channel: [ val(meta), path(ids), path(zip) ]

    main:

    ch_consensus
        .join( ch_structures.map { meta, _ids, zip -> [ meta, zip ] } )
        .set { ch_choppdbzip }

    CHOPPDBZIP (
        ch_choppdbzip
    )

    CHUNKSMD5 (
        CHOPPDBZIP.out.chopped_pdbs
    )

    emit:
    chopped_pdb = CHOPPDBZIP.out.chopped_pdbs // channel: [ val(meta), path(tar.gz) ]
    error_pdb   = CHOPPDBZIP.out.error_pdbs   // channel: [ val(meta), path(tar.gz) ]
    chunk_md5   = CHUNKSMD5.out.md5s          // channel: [ val(meta), path(tsv) ]

}
