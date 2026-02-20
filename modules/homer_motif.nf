process homer_motif {
    tag "${peak_file}"
    publishDir "${params.homer_output}/motif", mode: 'copy'

    input:
    path peak_file

    output:
    path "${peak_file.simpleName}_motifs/"
    path "${peak_file.simpleName}.peakfile.txt", optional: true

    script:
    def motif_len  = params.motif_len  ?: "6,8,10,12"
    def motif_size = params.motif_size ?: "200"
    def motif_mis  = params.motif_mis  ?: 2
    def motif_S    = params.motif_S    ?: 25
    def motif_p    = params.motif_p    ?: task.cpus
    def use_bed2pos = (params.use_bed2pos == null) ? true : params.use_bed2pos
    """
    set -eux

    INPUT_PEAKS="${peak_file}"
    if [[ "${use_bed2pos}" == "true" ]]; then
      bed2pos.pl ${peak_file} > ${peak_file.simpleName}.peakfile.txt
      INPUT_PEAKS="${peak_file.simpleName}.peakfile.txt"
    fi

    findMotifsGenome.pl \
        \$INPUT_PEAKS \
        ${params.genome} \
        ${peak_file.simpleName}_motifs \
        -size ${motif_size} \
        -len ${motif_len} \
        -mis ${motif_mis} \
        -S ${motif_S} \
        -p ${motif_p}
    """
}
