include { UNTAR                   } from '../../../modules/nf-core/untar/main'
include { FOLDSEEK_EASYSEARCH     } from '../../../modules/nf-core/foldseek/easysearch/main'
include { FOLDSEEK_PROCESSRESULTS } from '../../../modules/local/foldseek/processresults/main'

workflow HOMCHECK {

    take:
    ch_domains          // channel: [ val(meta), path(domains) ], chopped domain structures per chunk (.tar.gz, directory or PDB files)
    ch_foldseek_db      // channel: [ val(meta2), path(db) ], CATH Foldseek database as a directory or .tar.gz; meta2.id is the database name inside it
    cath_domain_list    // value channel: path(cath_domain_list), CATH domain list covering every database entry

    main:

    // Unpack the database if it is supplied as an archive
    def ch_foldseek_db_input = ch_foldseek_db.branch { _meta, db ->
        archive: db.name.endsWith('.tar.gz') || db.name.endsWith('.tgz')
        directory: true
    }

    //
    // MODULE: Unpack the CATH Foldseek database
    //
    UNTAR ( ch_foldseek_db_input.archive )

    // Database directory, reused for every chunk: [ val(meta2), path(db) ]
    def ch_foldseek_db_dir = ch_foldseek_db_input.directory
        .mix( UNTAR.out.untar )
        .first()

    //
    // MODULE: Search each chunk of domains against the CATH database
    //
    FOLDSEEK_EASYSEARCH ( ch_domains, ch_foldseek_db_dir )

    //
    // MODULE: Keep the best CATH hit per domain and classify it (H, T or N)
    //
    FOLDSEEK_PROCESSRESULTS ( FOLDSEEK_EASYSEARCH.out.aln, cath_domain_list )

    emit:
    foldseek_hits = FOLDSEEK_PROCESSRESULTS.out.tsv // channel: [ val(meta), path(tsv) ], best CATH hit per domain
    foldseek_aln  = FOLDSEEK_EASYSEARCH.out.aln     // channel: [ val(meta), path(m8) ], all Foldseek hits
}
