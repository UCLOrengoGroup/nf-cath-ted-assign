include { CREATEINPUTZIP                 } from '../../../modules/local/createinputzip/main'
include { CHUNKBYZIP                     } from '../../../modules/local/chunkbyzip/main'
include { CHUNKBYZIP as CHUNKBYZIP_HEAVY } from '../../../modules/local/chunkbyzip/main'
include { RENUMBERPDB                    } from '../../../modules/local/renumberpdb/main'
include { FILTERPDB                      } from '../../../modules/local/filterpdb/main'
include { GETUNIPROT                     } from '../../../modules/local/getuniprot/main'

workflow PREPARE_INPUT {

    take:
    ch_zip_file    // channel: [ val(meta), path(zip) ], meta: [ id, structure_type ]
    chunk_size       // integer: maximum number of structures per chunk for validation and renumbering
    heavy_chunk_size // integer: maximum number of structures per segmentation chunk
    max_entries      // integer: maximum number of structures to process, or null for all
    min_residues   // integer: structures with this many residues or fewer are rejected
    max_residues   // integer: structures with this many residues or more are rejected

    main:

    //
    // MODULE: List the structures in each input zip
    //
    CREATEINPUTZIP ( ch_zip_file )

    // One item per structure: [ val(meta), val(structure_id), val(zip_name) ]
    def ch_input_mapping = CREATEINPUTZIP.out.input_mapping
        .flatMap { meta, tsv ->
            tsv.splitCsv(sep: '\t', strip: true)
                .findAll { row -> row[0] && row[1] }
                .collect { row -> [ meta, row[0], row[1] ] }
        }
        .unique()

    // Optionally keep the first max_entries structures, sorted by ID so the selection is reproducible
    def ch_selected = max_entries
        ? ch_input_mapping
            .toSortedList { a, b -> a[1] <=> b[1] }
            .flatMap { structures -> structures }
            .take(max_entries)
        : ch_input_mapping

    // Input zips keyed by sample ID: [ val(id), val(meta), path(zip) ]
    def ch_zips = ch_zip_file.map { meta, zip -> [ meta.id, meta, zip ] }

    // Per input zip, a TSV of structure ID and zip name: [ val(meta), path(tsv) ]
    def ch_all_ids_mapping = ch_selected
        .collectFile(sort: true, newLine: true) { meta, structure_id, zip_name ->
            [ "${meta.id}.all_ids_mapping.tsv", "${structure_id}\t${zip_name}" ]
        }
        .map { tsv -> [ tsv.name - '.all_ids_mapping.tsv', tsv ] }
        .join( ch_zips.map { id, meta, _zip -> [ id, meta ] } )
        .map { _id, tsv, meta -> [ meta, tsv ] }

    //
    // MODULE: Split each zip's structures into chunks
    //
    CHUNKBYZIP ( ch_all_ids_mapping, chunk_size )

    // One item per chunk, chunk index added to meta: [ val(meta), path(ids), path(zip) ]
    def ch_chunks = CHUNKBYZIP.out.chunk_folder
        .transpose()
        .map { meta, ids ->
            // Chunk files are named <zip>_ids_mapping.<chunk_id>.txt
            def chunk_id = ids.name.tokenize('.')[-2].toInteger()
            [ meta.id, meta + [ chunk_id: chunk_id ], ids ]
        }
        .combine( ch_zips.map { id, _meta, zip -> [ id, zip ] }, by: 0 )
        .map { _id, meta, ids, zip -> [ meta, ids, zip ] }
        .branch { meta, _ids, _zip ->
            experimental: meta.structure_type == 'experimental'
            predicted: true
        }

    //
    // MODULE: Renumber experimental structures; filtering then reads the renumbered zip
    //
    RENUMBERPDB ( ch_chunks.experimental )

    def ch_to_filter = ch_chunks.predicted.mix(
        ch_chunks.experimental
            .map { meta, ids, _zip -> [ meta, ids ] }
            .join( RENUMBERPDB.out.zip )
    )

    //
    // MODULE: Keep single-model, single-chain structures within the residue-count range
    //
    FILTERPDB ( ch_to_filter, min_residues, max_residues )

    //
    // MODULE: Fetch UniProt taxonomy, which only applies to predicted (AlphaFold DB) structures
    //
    GETUNIPROT ( ch_chunks.predicted.map { meta, ids, _zip -> [ meta, ids ] } )

    // Per sample, a TSV of accepted structure ID, zip name and residue count: [ val(meta), path(tsv) ]
    // The zip is the input zip, or for experimental structures the renumbered zip of their chunk
    def ch_filtered_ids_mapping = FILTERPDB.out.metadata
        .flatMap { meta, metadata ->
            metadata.splitCsv(header: true, sep: '\t')
                .findAll { row -> row.status == 'accepted' }
                .collect { row -> [ meta.id, "${row.pdb_id}\t${row.zip_name}\t${row.residue_count}" ] }
        }
        .collectFile(sort: true, newLine: true) { id, row -> [ "${id}.filtered_ids_mapping.tsv", row ] }
        .map { tsv -> [ tsv.name - '.filtered_ids_mapping.tsv', tsv ] }
        .join( ch_zips.map { id, meta, _zip -> [ id, meta ] } )
        .map { _id, tsv, meta -> [ meta, tsv ] }

    //
    // MODULE: Re-chunk accepted structures for segmentation, filled from shortest to longest
    //
    CHUNKBYZIP_HEAVY ( ch_filtered_ids_mapping, heavy_chunk_size )

    // Zips that segmentation chunks read from, keyed by sample ID and file name: [ val(id), val(zip_name), path(zip) ]
    def ch_zips_by_name = ch_to_filter
        .map { meta, _ids, zip -> [ meta.id, zip.name, zip ] }
        .unique()

    // One item per segmentation chunk, with the chunk index and the residue count of its longest
    // structure (used to size segmentation resources) added to meta: [ val(meta), path(ids), path(zip) ]
    def ch_heavy_chunks = CHUNKBYZIP_HEAVY.out.tsv
        .join( CHUNKBYZIP_HEAVY.out.chunk_folder )
        .flatMap { meta, mapping, chunk_files ->
            def chunk_files_by_name = chunk_files.collectEntries { chunk_file -> [ chunk_file.name, chunk_file ] }
            // Mapping columns: chunk_id, chunk_file, zip_name, max_residues
            mapping.splitCsv(header: true, sep: '\t').collect { row ->
                [
                    meta.id,
                    row.zip_name,
                    meta + [ chunk_id: row.chunk_id.toInteger(), max_residues: row.max_residues.toInteger() ],
                    chunk_files_by_name[ row.chunk_file.tokenize('/')[-1] ]
                ]
            }
        }
        .combine( ch_zips_by_name, by: [ 0, 1 ] )
        .map { _id, _zip_name, meta, ids, zip -> [ meta, ids, zip ] }

    emit:
    structures      = ch_heavy_chunks         // channel: [ val(meta), path(ids), path(zip) ], segmentation chunks of accepted structures
    filter_metadata = FILTERPDB.out.metadata  // channel: [ val(meta), path(tsv) ]
    resmaps         = RENUMBERPDB.out.resmaps // channel: [ val(meta), path(zip) ]
    renumber_errors = RENUMBERPDB.out.errors  // channel: [ val(meta), path(tsv) ]
    uniprot         = GETUNIPROT.out.tsv      // channel: [ val(meta), path(tsv) ]
}
