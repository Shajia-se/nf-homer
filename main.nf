#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.mode       = params.mode ?: "annotate"    // annotate / motif / both
params.peaks      = params.peaks ?: null
params.genome     = params.genome ?: "mm10"
params.outdir     = params.outdir ?: "homer_output"

include { homer_annotate } from './modules/homer_annotate.nf'
include { homer_motif    } from './modules/homer_motif.nf'

workflow {

    if( params.mode == "annotate" ) {
        homer_annotate( params.peaks )
    }
    else if( params.mode == "motif" ) {
        homer_motif( params.peaks )
    }
    else if( params.mode == "both" ) {
        annotated = homer_annotate( params.peaks )
        homer_motif( annotated )
    }
    else {
        exit 1, "Unknown mode: ${params.mode}. Supported: annotate / motif / both"
    }
}
