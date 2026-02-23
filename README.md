# nf-homer

HOMER annotation and motif module for peak sets.

## Modes

- `annotate`
- `motif`
- `both`
- `motif_compare` (target vs custom background)
- `motif_and_compare` (default; runs `motif` + `motif_compare`)

## Input

Standard modes (`annotate` / `motif` / `both` / `motif_and_compare` motif part):
- `params.peaks` (default: IDR chr-sorted BED)
- optional `--idr_pairs_csv` to restrict to current IDR pair names

`motif_compare` input:
1. `--motif_compare_sheet` CSV (explicit), or
2. auto from `--samples_master` + `--diffbind_output` (fixed to `TG.vs.WT` naming in this project)

### Explicit `motif_compare_sheet` format
```text
group_name,target_bed,background_bed
```

### Auto compare behavior
- expects exactly 2 enabled non-control conditions from `samples_master`
- reads:
  - `condition_unique_up.TG.vs.WT.bed`
  - `condition_unique_down.TG.vs.WT.bed`
  from `diffbind_output`
- builds two comparisons automatically:
  - `TG_unique_vs_WT_bg`
  - `WT_unique_vs_TG_bg`

## Output

- Annotate: `${sample}.annotated.txt`
- Motif: `${sample}_motifs/`
- Motif compare: `${group_name}_motifs/` in `${homer_output}/motif_compare`

## Key Parameters

- `mode` (default: `motif_and_compare`)
- `use_bed2pos` (default: `true`)
- `motif_size` (default: `200`)
- `motif_len` (default: `6,8,10,12`)
- `motif_mis` (default: `2`)
- `motif_S` (default: `25`)

## Run

Default recommended (motif + compare):
```bash
nextflow run main.nf -profile hpc
```

Explicit target/background compare:
```bash
nextflow run main.nf -profile hpc \
  --mode motif_compare \
  --motif_compare_sheet motif_compare_sheet.csv
```

Motif only:
```bash
nextflow run main.nf -profile hpc --mode motif
```
