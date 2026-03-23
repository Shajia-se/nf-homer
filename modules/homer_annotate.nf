process homer_annotate {
    tag "${label}"
    publishDir "${params.homer_output}/annotate", mode: 'copy'

    input:
    tuple val(label), path(peak_file)

    output:
    path "${label}.annotated.txt"

    script:
    """
    annotatePeaks.pl ${peak_file} ${params.genome} > ${label}.annotated.txt
    """
}
