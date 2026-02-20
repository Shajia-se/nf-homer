# nf-homer

HOMER annotation and motif module for IDR-filtered peaks.

## Modes
- `annotate`
- `motif`
- `both`

## Input
- `params.peaks` (default: IDR chr-sorted BED)

## Output
- Annotate: `${sample}.annotated.txt`
- Motif: `${sample}_motifs/`

## Key Parameters (aligned to colleague script)
- `use_bed2pos` (default: `true`)
- `motif_size` (default: `200`)
- `motif_len` (default: `6,8,10,12`)
- `motif_mis` (default: `2`)
- `motif_S` (default: `25`)
- motif threads follow task cpus

## Run
```bash
nextflow run main.nf -profile hpc --mode both
```
