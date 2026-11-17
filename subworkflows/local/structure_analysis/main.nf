include { STRIDE                 } from '../../../modules/local/stride/main'
include { MEASUREGLOBULARITY     } from '../../../modules/local/measureglobularity/main'
include { DOMAINQUALITY          } from '../../../modules/local/domainquality/main'
include { PLDDT                  } from '../../../modules/local/plddt/main'
include { GAWK as JOIN_PLDDT_MD5 } from '../../../modules/nf-core/gawk/main'

workflow STRUCTURE_ANALYSIS {

    take:
    ch_chopped_pdbs // channel: [ val(meta), path(tar.gz) ]
    ch_chopped_pdbs_md5 // channel: [ val(meta), path(md5) ]

    main:

    STRIDE (
        ch_chopped_pdbs
    )

    MEASUREGLOBULARITY (
        ch_chopped_pdbs
    )

    DOMAINQUALITY (
        ch_chopped_pdbs
    )

    PLDDT (
        ch_chopped_pdbs
    )

    ch_chopped_pdbs_md5
        .join( PLDDT.out.plddt, failOnMismatch: true, failOnDuplicate: true )
        .map { meta, md5, plddt -> [ meta, [ md5, plddt ], 'tsv' ] }
        .set { ch_join_plddt_md5 }

    JOIN_PLDDT_MD5 (
        ch_join_plddt_md5,
        [],
        false
    )


    emit:
    stride_output = STRIDE.out.summary // channel: [ val(meta), path(stride_output) ]
    globularity_output = MEASUREGLOBULARITY.out.globularity // channel: [ val(meta), path(globularity_output) ]
    domainquality_output = DOMAINQUALITY.out.domainquality // channel: [ val(meta), path(domain_quality.csv) ]
    join_plddt_md5_output = JOIN_PLDDT_MD5.out.output // channel: [ val(meta), path(join_plddt_md5_output) ]
}
