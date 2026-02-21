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

process homer_motif_compare {
    tag "${group_name}"
    publishDir "${params.homer_output}/motif_compare", mode: 'copy'

    input:
    tuple val(group_name), path(target_bed), path(background_bed)

    output:
    path "${group_name}_motifs/"
    path "${group_name}.target.peakfile.txt", optional: true
    path "${group_name}.background.peakfile.txt", optional: true

    script:
    def motif_len  = params.motif_len  ?: "6,8,10,12"
    def motif_size = params.motif_size ?: "200"
    def motif_mis  = params.motif_mis  ?: 2
    def motif_S    = params.motif_S    ?: 25
    def motif_p    = params.motif_p    ?: task.cpus
    def use_bed2pos = (params.use_bed2pos == null) ? true : params.use_bed2pos
    """
    set -eux

    TARGET_INPUT="${target_bed}"
    BG_INPUT="${background_bed}"
    if [[ "${use_bed2pos}" == "true" ]]; then
      bed2pos.pl ${target_bed} > ${group_name}.target.peakfile.txt
      bed2pos.pl ${background_bed} > ${group_name}.background.peakfile.txt
      TARGET_INPUT="${group_name}.target.peakfile.txt"
      BG_INPUT="${group_name}.background.peakfile.txt"
    fi

    findMotifsGenome.pl \\
        \$TARGET_INPUT \\
        ${params.genome} \\
        ${group_name}_motifs \\
        -bg \$BG_INPUT \\
        -size ${motif_size} \\
        -len ${motif_len} \\
        -mis ${motif_mis} \\
        -S ${motif_S} \\
        -p ${motif_p}
    """
}
