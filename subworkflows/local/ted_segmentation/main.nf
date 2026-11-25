include { TED_MERIZO                 } from '../../../modules/local/ted/merizo/main'
include { TED_UNIDOC                       } from '../../../modules/local/ted/unidoc/main'
include { TED_CHAINSAW                     } from '../../../modules/local/ted/chainsaw/main'
include { TED_CONSENSUS                     } from '../../../modules/local/ted/consensus/main'

workflow TED_SEGMENTATION {

    take:
    ch_structures // channel: [ val(meta), path(ids), path(zip) ]
    ch_weights    // channel: [ path(pt), path(pt), path(pt) ]
    
    main:

    //
    // MODULE: Run TED chainsaw
    //
    TED_CHAINSAW ( ch_structures )

    //
    // MODULE: Run TED merizo
    //
    TED_MERIZO ( ch_structures, ch_weights )

    TED_MERIZO.out.merizo
        .join(ch_structures)
        .multiMap { meta, merizo, ids, zip ->
            structures: tuple( meta, ids, zip )
            merizo: tuple( meta, merizo )
        }
        .set { ch_unidoc }

    //
    // MODULE: Run TED unidoc
    //
    TED_UNIDOC ( ch_unidoc.structures, ch_unidoc.merizo )

    TED_CHAINSAW.out.chainsaw
        .join(TED_MERIZO.out.merizo)
        .join(TED_UNIDOC.out.unidoc)
        .multiMap { meta, chainsaw, merizo, unidoc ->
            chainsaw: tuple( meta, chainsaw )
            merizo: tuple( meta, merizo )
            unidoc: tuple( meta, unidoc )
        }
        .set { ch_consensus }

    //
    // MODULE: Run TED consensus
    //
    TED_CONSENSUS (
        ch_consensus.chainsaw,
        ch_consensus.merizo,
        ch_consensus.unidoc
    )

emit:
consensus = TED_CONSENSUS.out.consensus  // channel: [ val(meta), path(txt) ]
chainsaw  = TED_CHAINSAW.out.chainsaw    // channel: [ val(meta), path(txt) ]
merizo    = TED_MERIZO.out.merizo        // channel: [ val(meta), path(txt) ]
unidoc    = TED_UNIDOC.out.unidoc        // channel: [ val(meta), path(txt) ]

}
