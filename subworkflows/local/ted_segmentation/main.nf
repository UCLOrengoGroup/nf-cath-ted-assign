include { TED_MERIZO                 } from '../../../modules/local/ted/merizo/main'
include { TED_UNIDOC                       } from '../../../modules/local/ted/unidoc/main'
include { TED_CHAINSAW                     } from '../../../modules/local/ted/chainsaw/main'
include { TED_CONSENSUS                     } from '../../../modules/local/ted/consensus/main'

workflow TED_SEGMENTATION {

    take:
    ch_structures // channel: [ val(meta), path(ids), path(zip) ]

    main:

    //
    // MODULE
    //
    TED_CHAINSAW ( ch_structures )

    //
    // MODULE
    //
    TED_MERIZO ( ch_structures )

    //
    // MODULE
    //
    TED_MERIZO.out.merizo
        .join(ch_structures)
        .multiMap { meta, merizo, ids, zip -> 
            structures: tuple( meta, ids, zip )
            merizo: tuple( meta, merizo )
        }
        .set { ch_unidoc }

    TED_UNIDOC ( ch_unidoc.structures, ch_unidoc.merizo )

    //
    // MODULE
    //
    TED_CHAINSAW.out.chainsaw
        .join(TED_MERIZO.out.merizo)
        .join(TED_UNIDOC.out.unidoc)
        .multiMap { meta, chainsaw, merizo, unidoc ->
            chainsaw: tuple( meta, chainsaw )
            merizo: tuple( meta, merizo )
            unidoc: tuple( meta, unidoc )
        }
        .set { ch_consensus }

    // MODULE
    TED_CONSENSUS (
        ch_consensus.chainsaw,
        ch_consensus.merizo,
        ch_consensus.unidoc
    )

}
