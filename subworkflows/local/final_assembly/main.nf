include { TRANSFORMCONSENSUS } from '../../../modules/local/transformconsensus/main'
include { COLLECTRESULTS } from '../../../modules/local/collectresults/main'
include { COLLECTRESULTSFINAL } from '../../../modules/local/collectresultsfinal/main'
include { BENCHMARK } from '../../../modules/local/benchmark/main'

workflow FINAL_ASSEMBLY {

    take:
    ch_consensus
    ch_md5
    ch_stride
    ch_merizo
    ch_unidoc
    ch_chainsaw
    ch_globularity
    ch_plddt
    ch_domain_quality
    ch_uniprot
    ch_foldseek

    main:

    // Collect files for TRANSFORMCONSENSUS module
    ch_consensus
        .map { _meta, consensus -> consensus }
        .collectFile(
            name: 'collected_consensus.tsv',
            sort: 'hash', // So it caches
            storeDir: "${params.outdir}/consensus"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_consensus_collected }

    ch_md5
        .map { _meta, md5 -> md5}
        .collectFile(
            name: 'collected_md5.tsv',
            sort: 'hash',
            skip: 1,
            keepHeader: true,
            storeDir: "${params.outdir}/md5"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_md5_collected }

    ch_stride
        .map { _meta, stride -> stride }
        .collectFile(
            name: 'collected_stride.tsv',
            skip: 1,
            sort: 'hash',
            keepHeader: true,
            storeDir: "${params.outdir}/stride"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_stride_collected }

    //
    // MODULE: Transform consensus output to final output format
    //
    TRANSFORMCONSENSUS (
        ch_consensus_collected,
        ch_md5_collected,
        ch_stride_collected
    )

    // Collect files for COLLECTRESULTS module (segmentation outputs have no header)
    ch_chainsaw
        .map { _meta, chainsaw -> chainsaw }
        .collectFile(
            name: 'collected_chainsaw.tsv',
            sort: 'hash',
            storeDir: "${params.outdir}/chainsaw"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_chainsaw_collected }

    ch_merizo
        .map { _meta, merizo -> merizo }
        .collectFile(
            name: 'collected_merizo.tsv',
            sort: 'hash',
            storeDir: "${params.outdir}/merizo"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_merizo_collected }

    ch_unidoc
        .map { _meta, unidoc -> unidoc }
        .collectFile(
            name: 'collected_unidoc.tsv',
            sort: 'hash',
            storeDir: "${params.outdir}/unidoc"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_unidoc_collected }

    //
    // MODULE: Collect results from segmentation modules (chainsaw, merizo, unidoc)
    //
    COLLECTRESULTS (
        ch_chainsaw_collected,
        ch_merizo_collected,
        ch_unidoc_collected
    )

    // Collect files for COLLECTRESULTSFINAL module
    ch_globularity
        .map { _meta, globularity -> globularity }
        .collectFile(
            name: 'collected_globularity.tsv',
            sort: 'hash',
            skip: 1,
            keepHeader: true,
            storeDir: "${params.outdir}/globularity"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_globularity_collected }

    // pLDDT with md5 (gawk output) has no header
    ch_plddt
        .map { _meta, plddt -> plddt }
        .collectFile(
            name: 'collected_plddt_with_md5.tsv',
            sort: 'hash',
            storeDir: "${params.outdir}/plddt"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_plddt_collected }

    ch_domain_quality
        .map { _meta, domain_quality -> domain_quality }
        .collectFile(
            name: 'collected_domain_quality.csv',
            sort: 'hash',
            skip: 1,
            keepHeader: true,
            storeDir: "${params.outdir}/domain_quality"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_domain_quality_collected }

    ch_uniprot
        .map { _meta, uniprot -> uniprot }
        .collectFile(
            name: 'collected_uniprot.tsv',
            sort: 'hash',
            skip: 1,
            keepHeader: true,
            storeDir: "${params.outdir}/uniprot"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_uniprot_collected }

    ch_foldseek
        .map { _meta, foldseek -> foldseek }
        .collectFile(
            name: 'collected_foldseek.tsv',
            sort: 'hash',
            skip: 1,
            keepHeader: true,
            storeDir: "${params.outdir}/foldseek"
        )
        .map { file -> tuple( [id:'all'], file ) }
        .set { ch_foldseek_collected }

    // MODULE: Collect results from some modules (globularity, pLDDT, domain quality, uniprot, foldseek)
    COLLECTRESULTSFINAL (
        TRANSFORMCONSENSUS.out.tsv,
        ch_globularity_collected,
        ch_plddt_collected,
        ch_domain_quality_collected,
        ch_uniprot_collected,
        ch_foldseek_collected
    )

}
