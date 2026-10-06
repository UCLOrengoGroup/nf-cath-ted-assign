include { CREATEINPUTZIP } from '../../../modules/local/createinputzip/main.nf'

workflow PREPARE_INPUT {

    take:
    ch_zip_file // channel: [ val(meta), [ bam ] ]

    main:

    CREATEINPUTZIP ( 
        ch_zip_file
     )

    CREATEINPUTZIP.out.input_mapping
        .map { meta, tsv ->
            def splittsv = tsv.splitCsv(header:false, sep:'\t')
            [ meta, splittsv ]
        }
        .transpose()
        .map { meta, pdb_zip ->
            def pdb_id = pdb_zip[0]?.trim()
            def zip = pdb_zip[1]?.trim()
            def new_meta = meta + [ pdb_id: pdb_id ]
            [ new_meta, zip ]
        }
        .filter { meta, zip -> zip != '' && meta.pdb_id != '' }
        .unique()
        .toSortedList { a, b -> a[0].id <=> b[0].id ?: a[0].pdb_id <=> b[0].pdb_id } // Are PDB IDs unique? This is handling the case where they are not unique across files
        .flatMap() // Necessary because of toSortedList
        .view()
        .set { ch_input_mapping }

    //emit:
}
