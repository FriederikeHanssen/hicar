// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from '../functions'

params.options = [:]
options        = initOptions(params.options)

process MAPS_MAPS{
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) },
        enabled: options.publish

    conda (params.enable_conda ? "pandas=1.1.5" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pandas:1.1.5"
    } else {
        container "quay.io/biocontainers/pandas:1.1.5"
    }

    input:
    tuple val(meta), val(bin_size), path(macs2), path(long_bedpe, stageAs: "long/*"), path(short_bed, stageAs: "short/*"), path(background)

    output:
    tuple val(meta), val(bin_size), path(macs2), path(long_bedpe), path(short_bed), path(background), path("${meta.id}_${bin_size}/*"), emit: maps
    path "*.version.txt"          , emit: version

    script:
    def software  = "MAPS"
    """
    ## 2 steps
    ## step 1, prepare the config file for MAPS. The file will be used for multiple steps
    mkdir -p "${meta.id}_${bin_size}"
    make_maps_runfile.py \\
        "${meta.id}" \\
        "${meta.id}_${bin_size}/" \\
        $macs2 \\
        $background \\
        "long/" \\
        "short/" \\
        $bin_size \\
        0 \\
        "${meta.id}_${bin_size}/" \\
        ${options.args}
    ## step 2, parse the signals into .xor and .and files, details please refer: doi:10.1371/journal.pcbi.1006982
    ## by default, the sex chromosome will be excluded.
    MAPS.py "${meta.id}_${bin_size}/maps_${meta.id}.maps"

    echo '1.1.0' > ${software}.version.txt
    """
}
