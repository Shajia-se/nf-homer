#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.mode   = params.mode ?: "both"      // annotate / motif / both
params.homer_output = params.homer_output ?: "homer_output"

include { homer_annotate } from './modules/homer_annotate.nf'
include { homer_motif    } from './modules/homer_motif.nf'


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
    else if( params.mode == "both" ) {

        annotated = homer_annotate( peak_for_annotate )
        homer_motif( peak_for_motif )
    }
}
