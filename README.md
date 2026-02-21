# nf-homer

HOMER annotation and motif module for peak sets.

## Modes

- `annotate`
- `motif`
- `both`
- `motif_compare` (target vs custom background)

## Input

- Standard modes use `params.peaks` (default: IDR chr-sorted BED)
- `motif_compare` mode uses `--motif_compare_sheet` CSV:

```text
group_name,target_bed,background_bed
```

## Output

- Annotate: `${sample}.annotated.txt`
- Motif: `${sample}_motifs/`
- Motif compare: `${group_name}_motifs/` in `${homer_output}/motif_compare`

## Key Parameters

- `use_bed2pos` (default: `true`)
- `motif_size` (default: `200`)
- `motif_len` (default: `6,8,10,12`)
- `motif_mis` (default: `2`)
- `motif_S` (default: `25`)

## Run

Standard motif:

```bash
nextflow run main.nf -profile hpc --mode motif
```

Target vs background motif:

```bash
nextflow run main.nf -profile hpc \
  --mode motif_compare \
  --motif_compare_sheet motif_compare_sheet.csv
```
