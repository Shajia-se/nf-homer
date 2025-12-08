process homer_annotate {
    tag "${peak_file}"
    publishDir "${params.homer_output}/annotate", mode: 'copy'

    input:
    path peak_file

    output:
    path "${peak_file.simpleName}.annotated.txt"

    script:
    """
    annotatePeaks.pl ${peak_file} ${params.genome} > ${peak_file.simpleName}.annotated.txt
    """
}
