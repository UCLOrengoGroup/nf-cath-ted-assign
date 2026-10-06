include { CREATEINPUTZIP } from '../../../modules/local/createinputzip/main.nf'
include { CHUNKBYZIP } from '../../../modules/local/chunkbyzip/main.nf'

workflow PREPARE_INPUT {

    take:
    ch_zip_file // channel: [ val(meta), [ bam ] ]

    main:

    CREATEINPUTZIP ( 
        ch_zip_file
    )

    CREATEINPUTZIP.out.input_mapping
        .map { meta, tsv ->
            def splittsv = tsv.splitCsv(header:false, sep:'\t') // Split TSV into a list of lists
            [ meta, splittsv ] // channel: [ val(meta), [ [ pdb_id, zip ] ] ]
        }
        .transpose() // Transpose to get a channel per PDB ID: [ meta, [ pdb_id, zip ] ]
        .map { meta, pdb_zip ->
            def pdb_id = pdb_zip[0]?.trim() // Trim whitespace from PDB ID
            def zip = pdb_zip[1]?.trim()
            def new_meta = meta + [ pdb_id: pdb_id ] // Add pdb_id to meta
            [ new_meta, zip ] // channel: [ val(new_meta), val(zip) ]
        }
        .filter { meta, zip -> zip && meta.pdb_id }
        .unique()
        .toSortedList { a, b -> a[0].id <=> b[0].id ?: a[0].pdb_id <=> b[0].pdb_id } // Are PDB IDs unique? This is handling the case where they are not unique across files
        .flatMap() // Necessary because of toSortedList output
        .set { ch_input_mapping }

    // Collect all input mapping files into a single TSV file
    ch_input_mapping
        .collectFile (
            sort: true,
            newLine: true,
            storeDir: "${params.outdir}/intermediante",
        ) { meta, zip -> 
            [ "${meta.id}.all_ids_mapping.tsv", "${meta.pdb_id}\t${zip}" ]
        }
        .map { tsv ->
            def id = tsv.name - '.all_ids_mapping.tsv' // Remove the suffix to get the ID
            [ [ id: id ], tsv ]
        }
        .view()
        .set { ch_all_ids_mapping }

    //
    CHUNKBYZIP (
        params.chunk_size,
        ch_all_ids_mapping
    )

}
