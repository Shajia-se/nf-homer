# nf-homer

`nf-homer` runs HOMER peak annotation, motif enrichment, and optional motif comparison.

This module is optional after IDR, consensus peaks, or DiffBind.

## Inputs

Select peak sources:

```bash
--homer_peak_sources idr,consensus_q0.01,consensus_q0.05
```

Provide only directories used by selected sources:

- `--idr_output`
- `--peak_consensus_output`
- `--diffbind_output`

For custom peaks:

```bash
--peaks "/path/to/*.bed"
```

For motif comparison, use:

```bash
--motif_compare_sheet /path/to/motif_compare_sheet.csv
```

or `samples_master` auto mode with exactly two enabled non-control conditions.

## Outputs

```text
${project_folder}/${homer_output}/
  annotate/
  motif/
  motif_compare/
```

## Run

```bash
nextflow run main.nf -profile hpc \
  --homer_peak_sources idr,consensus_q0.01,consensus_q0.05 \
  --idr_output /path/to/idr_output \
  --peak_consensus_output /path/to/peak_consensus_output \
  --project_folder /path/to/output_project
```

Actual execution should be tested where Nextflow is installed.
