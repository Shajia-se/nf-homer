#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.mode   = params.mode ?: "both"      // annotate / motif / both / motif_compare
params.homer_output = params.homer_output ?: "homer_output"

include { homer_annotate } from './modules/homer_annotate.nf'
include { homer_motif; homer_motif_compare } from './modules/homer_motif.nf'


workflow {

    Channel
        .fromPath(params.peaks)
        .ifEmpty { exit 1, "ERROR: No peak files found for pattern: ${params.peaks}" }
        .map { pf ->
            def basename      = pf.simpleName
            def anno_out_file = file("${params.homer_output}/annotate/${basename}.annotated.txt")
            def motif_out_dir = file("${params.homer_output}/motif/${basename}_motifs")
            tuple(pf, anno_out_file, motif_out_dir)
        }
        .set { peak_meta }   

    peak_for_annotate = peak_meta
        .filter { pf, anno, motif ->
            !anno.exists()
        }
        .map { pf, anno, motif -> pf }     

    peak_for_motif = peak_meta
        .filter { pf, anno, motif ->
            !motif.exists()
        }
        .map { pf, anno, motif -> pf }

    if( params.mode == "annotate" ) {

        homer_annotate( peak_for_annotate )
    }
    else if( params.mode == "motif" ) {

        homer_motif( peak_for_motif )
    }
    else if( params.mode == "motif_compare" ) {
        if( !params.motif_compare_sheet ) {
            exit 1, "ERROR: mode=motif_compare requires --motif_compare_sheet (CSV: group_name,target_bed,background_bed)"
        }
        Channel
            .fromPath(params.motif_compare_sheet, checkIfExists: true)
            .splitCsv(header: true)
            .map { row ->
                assert row.group_name && row.target_bed && row.background_bed : "motif_compare_sheet must contain: group_name,target_bed,background_bed"
                def t = file(row.target_bed.toString())
                def b = file(row.background_bed.toString())
                assert t.exists() : "target_bed not found for ${row.group_name}: ${t}"
                assert b.exists() : "background_bed not found for ${row.group_name}: ${b}"
                tuple(row.group_name.toString(), t, b)
            }
            .set { compare_input }

        homer_motif_compare(compare_input)
    }
    else if( params.mode == "both" ) {

        annotated = homer_annotate( peak_for_annotate )
        homer_motif( peak_for_motif )
    }
}
