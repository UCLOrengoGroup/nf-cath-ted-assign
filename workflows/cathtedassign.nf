/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { PREPARE_INPUT          } from '../subworkflows/local/prepare_input/main.nf'
include { TED_SEGMENTATION       } from '../subworkflows/local/ted_segmentation/main.nf'
include { POST_TED_PROCESSING    } from '../subworkflows/local/post_ted_processing/main.nf'
include { STRUCTURE_ANALYSIS     } from '../subworkflows/local/structure_analysis/main.nf'
include { FOLDSEEK               } from '../subworkflows/local/foldseek/main.nf'
include { FINAL_ASSEMBLY          } from '../subworkflows/local/final_assembly/main.nf'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_cathtedassign_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CATHTEDASSIGN {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    chunk_size
    heavy_chunk_size
    max_entries
    min_chain_residues
    max_chain_residues
    foldseek_db
    foldseek_lookup
    foldseek_chunks_per_batch
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    //
    // SUBWORKFLOW PREPARE_INPUT: List, chunk, renumber (experimental only) and filter input structures
    //
    PREPARE_INPUT (
        ch_samplesheet,
        chunk_size,
        heavy_chunk_size,
        max_entries,
        min_chain_residues,
        max_chain_residues,
        foldseek_db,
        foldseek_lookup
    )

    //
    // SUBWORKFLOW TED_SEGMENTATION: Segment structures into domains using TED
    //
    TED_SEGMENTATION (
        PREPARE_INPUT.out.structures
    )

    //
    // SUBWORKFLOW POST_TED_PROCESSING: Post-process TED output to generate chopped domain PDBs and their sequence MD5s
    //
    POST_TED_PROCESSING (
        TED_SEGMENTATION.out.consensus,
        PREPARE_INPUT.out.structures
    )

    //
    // SUBWORKFLOW STRUCTURE_ANALYSIS: Analyze chopped PDBs and generate STRIDE summaries
    //
    STRUCTURE_ANALYSIS (
        POST_TED_PROCESSING.out.chopped_pdb,
        POST_TED_PROCESSING.out.domain_md5
    )

    //
    // SUBWORKFLOW FOLDSEEK: Search chopped PDBs against a target database using Foldseek
    //
    FOLDSEEK (
        POST_TED_PROCESSING.out.chopped_pdb,
        PREPARE_INPUT.out.target_db,
        PREPARE_INPUT.out.lookup_table,
        foldseek_chunks_per_batch
    )

    //
    // SUBWORKFLOW FINAL_ASSEMBLY: Assemble final output files and generate summary reports
    //
    FINAL_ASSEMBLY (
        TED_SEGMENTATION.out.consensus,
        POST_TED_PROCESSING.out.domain_md5,
        STRUCTURE_ANALYSIS.out.stride_output,
        TED_SEGMENTATION.out.merizo,
        TED_SEGMENTATION.out.unidoc,
        TED_SEGMENTATION.out.chainsaw,
        STRUCTURE_ANALYSIS.out.globularity_output,
        STRUCTURE_ANALYSIS.out.join_plddt_md5_output,
        STRUCTURE_ANALYSIS.out.domainquality_output,
        PREPARE_INPUT.out.uniprot,
        FOLDSEEK.out.results
    )

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'cathtedassign_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'cathtedassign'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
