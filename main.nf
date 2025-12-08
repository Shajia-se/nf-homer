#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.mode   = params.mode ?: "annotate"      // annotate / motif / both
params.homer_output = params.homer_output ?: "homer_output"

include { homer_annotate } from './modules/homer_annotate.nf'
include { homer_motif    } from './modules/homer_motif.nf'


workflow {

    Channel
        .fromPath(params.peaks)
        .ifEmpty { exit 1, "ERROR: No peak files found for pattern: ${params.peaks}" }
        .set { peak_files }

    if( params.mode == "annotate" ) {
        homer_annotate( peak_files )
    }
    else if( params.mode == "motif" ) {
        homer_motif( peak_files )
    }
    else if( params.mode == "both" ) {
        annotated = homer_annotate( peak_files )
        homer_motif( annotated )
    }
}
