include { CHOPPDBZIP    } from '../../../modules/local/choppdbzip/main'
include { DOMAINMD5     } from '../../../modules/local/domainmd5/main'

workflow POST_TED_PROCESSING {

    take:
    ch_consensus  // channel: [ val(meta), path(consensus) ]
    ch_structures // channel: [ val(meta), path(ids), path(zip) ]

    main:

    // Join the consensus and structures channels to get the zip file for each consensus
    ch_consensus
        .join( ch_structures.map { meta, _ids, zip -> [ meta, zip ] } )
        .set { ch_choppdbzip }

    //
    // MODULE: Chop PDBs into domains
    //
    CHOPPDBZIP (
        ch_choppdbzip
    )

    //
    // MODULE: Generate sequence MD5s for each chopped domain
    //
    DOMAINMD5 (
        CHOPPDBZIP.out.chopped_pdbs
    )

    emit:
    chopped_pdb = CHOPPDBZIP.out.chopped_pdbs // channel: [ val(meta), path(tar.gz) ]
    error_pdb   = CHOPPDBZIP.out.error_pdbs   // channel: [ val(meta), path(tar.gz) ]
    domain_md5  = DOMAINMD5.out.md5           // channel: [ val(meta), path(tsv) ]

}
