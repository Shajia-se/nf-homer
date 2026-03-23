#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.mode   = params.mode ?: "motif_and_compare"      // annotate / motif / both / motif_compare / motif_and_compare
params.homer_output = params.homer_output ?: "homer_output"

include { homer_annotate } from './modules/homer_annotate.nf'
include { homer_motif; homer_motif_compare } from './modules/homer_motif.nf'


workflow {
    def build_motif_peaks = {
        if (params.peaks) {
            return Channel
                .fromPath(params.peaks, checkIfExists: true)
                .ifEmpty { exit 1, "ERROR: No peak files found for pattern: ${params.peaks}" }
                .map { pf -> tuple("custom__${pf.baseName}", pf) }
        }

        def peakSources = (params.homer_peak_sources ?: 'idr,consensus_q0.01,consensus_q0.05')
            .toString()
            .split(',')
            *.trim()
            .findAll { it }
            .unique()

        def peakFiles = []
        def addPeak = { label, peakPath ->
            if (!peakFiles.any { it.label == label }) {
                peakFiles << [label: label, peak: file(peakPath.toString())]
            }
        }

        if (peakSources.contains('idr')) {
            def idrDir = file(params.idr_output)
            assert idrDir.exists() : "idr_output not found: ${params.idr_output}"
            (idrDir.listFiles()?.findAll { f ->
                f.isFile() && f.name ==~ globToRegex(params.idr_peak_pattern ?: "*_idr.sorted.chr.bed")
            } ?: []).each { f ->
                addPeak("idr__${f.baseName}", f)
            }
        }

        if (peakSources.any { it in ['consensus', 'consensus_q0.01', 'consensus_q0.05'] }) {
            def consensusDir = file(params.peak_consensus_output)
            assert consensusDir.exists() : "peak_consensus_output not found: ${params.peak_consensus_output}"
            if (peakSources.any { it in ['consensus', 'consensus_q0.01'] }) {
                (file("${params.peak_consensus_output}/strict_q0.01").listFiles()?.findAll { f ->
                    f.isFile() && f.name ==~ globToRegex(params.consensus_peak_pattern ?: "*_consensus.bed")
                } ?: []).each { f ->
                    addPeak("consensus_q0.01__${f.baseName}", f)
                }
            }
            if (peakSources.contains('consensus_q0.05')) {
                (file("${params.peak_consensus_output}/consensus_q0.05").listFiles()?.findAll { f ->
                    f.isFile() && f.name ==~ globToRegex(params.consensus_peak_pattern ?: "*_consensus.bed")
                } ?: []).each { f ->
                    addPeak("consensus_q0.05__${f.baseName}", f)
                }
            }
        }

        if (peakSources.contains('diffbind')) {
            def diffbindDir = file(params.diffbind_output)
            assert diffbindDir.exists() : "diffbind_output not found: ${params.diffbind_output}"
            (diffbindDir.listFiles()?.findAll { f ->
                f.isFile() && f.name ==~ globToRegex(params.diffbind_peak_pattern ?: "*.bed")
            } ?: []).each { f ->
                addPeak("diffbind__${f.baseName}", f)
            }
        }

        return Channel
            .fromList(peakFiles.collect { tuple(it.label, it.peak) })
            .ifEmpty { exit 1, "ERROR: No peak files found for HOMER. Check configured source directories and patterns." }
    }

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
            exit 1, "ERROR: motif_compare requires --motif_compare_sheet or --samples_master auto mode."
        }

        def master = file(params.samples_master)
        assert master.exists() : "samples_master not found: ${params.samples_master}"

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

        def c1 = conds[0]
        def c2 = conds[1]
        def wt = conds.find { it.equalsIgnoreCase('WT') } ?: c1
        def tg = conds.find { it.equalsIgnoreCase('TG') } ?: (wt == c1 ? c2 : c1)
        def compareSources = (params.motif_compare_sources ?: 'idr,consensus_q0.01,consensus_q0.05')
            .toString()
            .split(',')
            *.trim()
            .findAll { it }
            .unique()

        def pairs = []

        if (compareSources.contains('idr')) {
            def idrDir = file(params.idr_output)
            assert idrDir.exists() : "idr_output not found: ${params.idr_output}"
            def target = file("${idrDir}/${tg}_idr.sorted.chr.bed")
            def bg = file("${idrDir}/${wt}_idr.sorted.chr.bed")
            assert target.exists() : "Auto motif_compare target not found (idr): ${target}"
            assert bg.exists() : "Auto motif_compare background not found (idr): ${bg}"
            pairs << tuple("idr_${tg}_vs_${wt}_bg", target, bg)
        }

        if (compareSources.any { it in ['consensus', 'consensus_q0.01'] }) {
            def target = file("${params.peak_consensus_output}/strict_q0.01/${tg}_consensus.bed")
            def bg = file("${params.peak_consensus_output}/strict_q0.01/${wt}_consensus.bed")
            assert target.exists() : "Auto motif_compare target not found (consensus_q0.01): ${target}"
            assert bg.exists() : "Auto motif_compare background not found (consensus_q0.01): ${bg}"
            pairs << tuple("consensus_q0.01_${tg}_vs_${wt}_bg", target, bg)
        }

        if (compareSources.contains('consensus_q0.05')) {
            def target = file("${params.peak_consensus_output}/consensus_q0.05/${tg}_consensus.bed")
            def bg = file("${params.peak_consensus_output}/consensus_q0.05/${wt}_consensus.bed")
            assert target.exists() : "Auto motif_compare target not found (consensus_q0.05): ${target}"
            assert bg.exists() : "Auto motif_compare background not found (consensus_q0.05): ${bg}"
            pairs << tuple("consensus_q0.05_${tg}_vs_${wt}_bg", target, bg)
        }

        Channel
            .fromList(pairs)
            .ifEmpty { exit 1, "ERROR: No motif_compare input pairs built. Check motif_compare_sources and input outputs." }
    }

    if( params.mode == "motif_compare" ) {
        def compare_input = build_compare_input()
        homer_motif_compare(compare_input)
    } else {
        build_motif_peaks()
            .ifEmpty { exit 1, "ERROR: No peak files found for HOMER motif enrichment." }
            .map { label, pf ->
                def anno_out_file = file("${params.homer_output}/annotate/${label}.annotated.txt")
                def motif_out_dir = file("${params.homer_output}/motif/${label}_motifs")
                tuple(label, pf, anno_out_file, motif_out_dir)
            }
            .set { peak_meta }

        peak_for_annotate = peak_meta
            .filter { label, pf, anno, motif ->
                !anno.exists()
            }
            .map { label, pf, anno, motif -> tuple(label, pf) }

        peak_for_motif = peak_meta
            .filter { label, pf, anno, motif ->
                !motif.exists()
            }
            .map { label, pf, anno, motif -> tuple(label, pf) }

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

def globToRegex(pattern) {
    '^' + pattern
        .replace('.', '\\.')
        .replace('*', '.*')
        .replace('?', '.') + '$'
}
