process homer_motif {
    tag "${peak_file}"
    publishDir "${params.homer_output}/motif", mode: 'copy'

    input:
    path peak_file

    output:
    path "${peak_file.simpleName}_motifs/"

    script:
    """
    findMotifsGenome.pl ${peak_file} ${params.genome} ${peak_file.simpleName}_motifs -size given
    """
}
