# nf-homer

Nextflow DSL2 module for HOMER-based peak annotation, motif enrichment, and motif comparison.

This module now supports three peak-set sources by default:
- `idr`
- `consensus`
- `diffbind`

It can run two distinct analyses:
- `motif enrichment`: run HOMER independently on each peak BED
- `motif_compare`: run HOMER with one BED as target and another BED as background

These are related but not the same:
- `motif enrichment` asks: which motifs are enriched in this peak set?
- `motif_compare` asks: which motifs are enriched in one peak set relative to another background peak set?

## Default Mode

Default mode is:

```text
motif_and_compare
```

That means one run will do both:
- motif enrichment on all default peak sources
- motif comparison using DiffBind condition-specific peaks

## Peak Inputs Used By Default

If you do not pass `--peaks`, the module automatically collects BED files from the following upstream outputs.

### 1. IDR peaks

Directory:
- `/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-idr/idr_output`

Pattern:
- `*_idr.sorted.chr.bed`

Typical files:
- `WT_idr.sorted.chr.bed`
- `TG_idr.sorted.chr.bed`

Use case:
- reproducible peak sets after IDR filtering

### 2. Consensus peaks

Directory:
- `/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-peak-consensus/peak_consensus_output`

Pattern:
- `*_consensus.bed`

Typical files:
- `WT_consensus.bed`
- `TG_consensus.bed`

Use case:
- overlap-based consensus peak sets from `strict_q0.01`

### 3. DiffBind unique peaks

Directory:
- `/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-diffbind/diffbind_output`

Pattern:
- `condition_unique_*.bed`

Typical files:
- `condition_unique_up.TG.vs.WT.bed`
- `condition_unique_down.TG.vs.WT.bed`

Use case:
- condition-specific differential binding peak sets

## What `motif enrichment` Runs On

By default, motif enrichment runs on all BED files collected from the three sources above.

In your current WT/TG project, that usually means:
- `WT_idr.sorted.chr.bed`
- `TG_idr.sorted.chr.bed`
- `WT_consensus.bed`
- `TG_consensus.bed`
- `condition_unique_up.TG.vs.WT.bed`
- `condition_unique_down.TG.vs.WT.bed`

Each one gets its own HOMER motif result directory.

## What `motif_compare` Runs On

By default, `motif_compare` does not use all peak sets.
It specifically uses the DiffBind condition-unique peak files.

Auto mode expects these two files in `diffbind_output`:
- `condition_unique_up.TG.vs.WT.bed`
- `condition_unique_down.TG.vs.WT.bed`

Then it builds two comparisons automatically:

1. `TG_unique_vs_WT_bg`
- target: `condition_unique_up.TG.vs.WT.bed`
- background: `condition_unique_down.TG.vs.WT.bed`

2. `WT_unique_vs_TG_bg`
- target: `condition_unique_down.TG.vs.WT.bed`
- background: `condition_unique_up.TG.vs.WT.bed`

So in practice:
- one comparison asks which motifs are enriched in TG-up peaks relative to WT-up peaks
- the other asks the reverse

## Input Modes

### Mode A: Fully automatic from pipeline outputs

This is the normal mode for your pipeline.

Required upstream outputs:
- `nf-idr`
- `nf-peak-consensus`
- `nf-diffbind`

Required metadata:
- `--samples_master`

You do not need `motif_compare_sheet.csv` in this mode.

### Mode B: Manual motif peak input

You can override automatic peak collection with:
- `--peaks`

Example:
```bash
nextflow run main.nf -profile hpc --mode motif --peaks '/path/to/*.bed'
```

### Mode C: Manual motif compare input

You can override automatic compare setup with:
- `--motif_compare_sheet`

Format:
```text
group_name,target_bed,background_bed
```

Use this only if you want custom target/background combinations.

## Main Parameters

### Core behavior
- `mode`
  - default: `motif_and_compare`
  - choices: `annotate`, `motif`, `both`, `motif_compare`, `motif_and_compare`

### Automatic peak-source control
- `homer_peak_sources`
  - default: `idr,consensus,diffbind`
- `idr_peak_pattern`
  - default: `*_idr.sorted.chr.bed`
- `consensus_peak_pattern`
  - default: `*_consensus.bed`
- `diffbind_peak_pattern`
  - default: `condition_unique_*.bed`

### Motif settings
- `use_bed2pos`
  - default: `true`
- `motif_size`
  - default: `200`
- `motif_len`
  - default: `6,8,10,12`
- `motif_mis`
  - default: `2`
- `motif_S`
  - default: `25`
- `motif_p`
  - default: `4`

## Outputs

Output root:
- `${project_folder}/${homer_output}`

### Annotation output
Directory:
- `${homer_output}/annotate/`

Files:
- `<peak_basename>.annotated.txt`

### Motif enrichment output
Directory:
- `${homer_output}/motif/`

Files:
- `<peak_basename>_motifs/`
- optional `<peak_basename>.peakfile.txt`

### Motif compare output
Directory:
- `${homer_output}/motif_compare/`

Files:
- `<group_name>_motifs/`
- optional `<group_name>.target.peakfile.txt`
- optional `<group_name>.background.peakfile.txt`

## Recommended Run Commands

### Default pipeline-style run

This runs motif enrichment plus motif comparison automatically:

```bash
nextflow run main.nf -profile hpc \
  --samples_master /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nextflow-chipseq/samples_master.csv \
  --idr_output /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-idr/idr_output \
  --peak_consensus_output /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-peak-consensus/peak_consensus_output \
  --diffbind_output /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-diffbind/diffbind_output
```

### Motif only

```bash
nextflow run main.nf -profile hpc --mode motif
```

### Motif compare only

```bash
nextflow run main.nf -profile hpc --mode motif_compare
```

### Custom compare sheet

```bash
nextflow run main.nf -profile hpc \
  --mode motif_compare \
  --motif_compare_sheet motif_compare_sheet.csv
```

## Notes

- `motif_compare_sheet.csv` is optional now; it is not required when automatic mode is used.
- Auto `motif_compare` is currently fixed to `TG.vs.WT` naming for this project.
- If DiffBind output naming changes, either update the module defaults or provide `--motif_compare_sheet` manually.
