#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.mode   = params.mode ?: "motif_and_compare"      // annotate / motif / both / motif_compare / motif_and_compare
params.homer_output = params.homer_output ?: "homer_output"

include { homer_annotate } from './modules/homer_annotate.nf'
include { homer_motif; homer_motif_compare } from './modules/homer_motif.nf'


workflow {
    def build_compare_input = {
        if (params.motif_compare_sheet) {
            return Channel
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
        }

        if (!params.samples_master) {
            exit 1, "ERROR: motif_compare requires --motif_compare_sheet or --samples_master + --diffbind_output auto mode."
        }

        def master = file(params.samples_master)
        assert master.exists() : "samples_master not found: ${params.samples_master}"
        def diffdir = file(params.diffbind_output)
        assert diffdir.exists() : "diffbind_output not found: ${params.diffbind_output}"

        def header = null
        def records = []
        master.eachLine { line, n ->
            if (!line?.trim()) return
            def cols = line.split(',', -1)*.trim()
            if (n == 1) {
                header = cols
            } else {
                def rec = [:]
                header.eachWithIndex { h, i -> rec[h] = i < cols.size() ? cols[i] : '' }
                records << rec
            }
        }
        assert header : "samples_master header not found: ${params.samples_master}"
        assert header.contains('condition') : "samples_master missing required column: condition"

        def isEnabled = { rec ->
            def v = rec.enabled?.toString()?.trim()?.toLowerCase()
            (v == null || v == '' || v == 'true')
        }
        def isControl = { rec ->
            rec.is_control?.toString()?.trim()?.toLowerCase() == 'true'
        }

        def conds = records
            .findAll { rec -> isEnabled(rec) && !isControl(rec) }
            .collect { it.condition?.toString()?.trim() }
            .findAll { it }
            .unique()

        if (conds.size() != 2) {
            exit 1, "ERROR: auto motif_compare currently expects exactly 2 enabled non-control conditions in samples_master."
        }

        // Fixed contrast naming for current project
        def up = file("${params.diffbind_output}/condition_unique_up.TG.vs.WT.bed")
        def down = file("${params.diffbind_output}/condition_unique_down.TG.vs.WT.bed")
        assert up.exists() : "Auto motif_compare target not found: ${up}"
        assert down.exists() : "Auto motif_compare background not found: ${down}"

        return Channel.fromList([
            tuple("TG_unique_vs_WT_bg", up, down),
            tuple("WT_unique_vs_TG_bg", down, up)
        ])
    }

    if( params.mode == "motif_compare" ) {
        def compare_input = build_compare_input()
        homer_motif_compare(compare_input)
    } else {
        def selectedPairs = null as Set
        if (params.idr_pairs_csv && file(params.idr_pairs_csv).exists()) {
            selectedPairs = [] as Set
            file(params.idr_pairs_csv).eachLine { line, n ->
                if (n == 1 || !line?.trim()) return
                def cols = line.split(',', -1)*.trim()
                if (cols.size() > 0 && cols[0]) selectedPairs << cols[0]
            }
        }

        Channel
            .fromPath(params.peaks, checkIfExists: true)
            .ifEmpty { exit 1, "ERROR: No peak files found for pattern: ${params.peaks}" }
            .filter { pf ->
                if (selectedPairs == null) return true
                selectedPairs.contains(pf.simpleName.toString())
            }
            .ifEmpty { exit 1, "ERROR: No peak files matched selected IDR pair names. Check --idr_pairs_csv and --peaks." }
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
        else if (params.mode == "motif_and_compare") {
            homer_motif(peak_for_motif)
            def compare_input = build_compare_input()
            homer_motif_compare(compare_input)
        } else {
            exit 1, "ERROR: Unsupported --mode '${params.mode}'. Use: annotate / motif / both / motif_compare / motif_and_compare"
        }
    }
}
