/*
================================================================================
    VALIDATE INPUTS
================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowHicar.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta,
                            params.gtf, params.bwa_index, params.gene_bed,
                            params.mappability]
for (param in checkPathParamList) {
    if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) {
    ch_input = Channel.fromPath("${params.input}")
                    .splitCsv(header: true, sep:",")
} else { exit 1, 'Input samplesheet not specified!' }

// set the restriction_sites
def RE_cutsite = [
    "mboi": "^GATC",
    "dpnii": "^GATC",
    "bglii": "^GATCT",
    "hindiii": "^AGCTT",
    "cviqi": "^TAC"]
if (!params.enzyme.toLowerCase() in RE_cutsite){
    exit 1, "Not supported yet!"
}
params.restriction_sites = RE_cutsite[params.enzyme.toLowerCase()]

/*
================================================================================
    CONFIG FILES
================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml",
                                checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ?
                                Channel.fromPath(params.multiqc_config) :
                                Channel.empty()
ch_circos_config         = file("$projectDir/assets/circos.conf",
                                checkIfExists: true)

/*
================================================================================
    TOOLS SOURCE FILE
================================================================================
*/

ch_juicer_tools              = file(params.juicer_tools_jar,
                                    checkIfExists: true)
ch_merge_map_py_source       = file(params.merge_map_py_source,
                                    checkIfExists: true)
ch_feature_frag2bin_source   = file(params.feature_frag2bin_source,
                                    checkIfExists: true)
ch_make_maps_runfile_source  = file(params.make_maps_runfile_source,
                                    checkIfExists: true)

/*
================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
================================================================================
*/

// Don't overwrite global params.modules,
// create a copy instead and use that within the main script.
def modules = params.modules.clone()

// Extract parameters from params.modules
def getParam(modules, module) {
    return modules[module]?:[:]
}
def getSubWorkFlowParam(modules, mods) {
    def Map options = [:]
    mods.each{
        val ->
        options[val] = modules[val]?:[:]
    }
    return options
}
// get relative folder for igv_track_files
def getPublishedFolder(modules, module, params){
    def mod = getParam(modules, module)
    def publish_dir = mod.publish_dir?:'.'
    def outdir = params.outdir?:'.'
    return outdir+'/'+publish_dir+'/'
}

//
// MODULE: Local to the pipeline
//
include { CHECKSUMS
    } from '../modules/local/checksums' addParams(
        options: getParam(modules, 'checksums') )
include { DIFFHICAR
    } from '../modules/local/bioc/diffhicar' addParams(
        options: getParam(modules, 'diffhicar'))
include { BIOC_CHIPPEAKANNO
    } from '../modules/local/bioc/chippeakanno' addParams(
        options: getParam(modules, 'chippeakanno'))
include { BIOC_CHIPPEAKANNO as BIOC_CHIPPEAKANNO_MAPS
    } from '../modules/local/bioc/chippeakanno' addParams(
        options: getParam(modules, 'chippeakanno_maps'))
include { BIOC_ENRICH
    } from '../modules/local/bioc/enrich' addParams(
        options: getParam(modules, 'enrichment'))
include { BIOC_TRACKVIEWER
    } from '../modules/local/bioc/trackviewer' addParams(
        options: getParam(modules, 'trackviewer'))
include { BIOC_TRACKVIEWER as BIOC_TRACKVIEWER_MAPS
    } from '../modules/local/bioc/trackviewer' addParams(
        options: getParam(modules, 'trackviewer_maps'))
include { IGV
    } from '../modules/local/igv' addParams(
        options: getParam(modules, 'igv'))

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PREPARE_GENOME
    } from '../subworkflows/local/preparegenome' addParams (
        options: getSubWorkFlowParam(modules, [
            'gunzip', 'gtf2bed', 'chromsizes', 'genomefilter',
            'bwa_index', 'gffread', 'digest_genome']) )
include { BAM_STAT
    } from '../subworkflows/local/bam_stats' addParams(
        options: getSubWorkFlowParam(modules, [
            'samtools_sort', 'samtools_index', 'samtools_stats',
            'samtools_flagstat', 'samtools_idxstats']))
include { PAIRTOOLS_PAIRE
    } from '../subworkflows/local/pairtools' addParams(
        options: getSubWorkFlowParam(modules, [
            'paritools_dedup', 'pairtools_flip', 'pairtools_parse',
            'pairtools_restrict', 'pairtools_select', 'pairtools_select_long',
            'pairs2hdf5', 'pairtools_sort', 'pairix',
            'reads_stat', 'reads_summary',
            'pairsqc', 'pairsplot']))
include { COOLER
    } from '../subworkflows/local/cooler' addParams(
        options: getSubWorkFlowParam(modules, [
            'cooler_cload', 'cooler_merge', 'cooler_zoomify',
            'cooler_dump_per_group', 'cooler_dump_per_sample',
            'dumpintrareads_per_group', 'dumpintrareads_per_sample',
            'juicer']))
include { ATAC_PEAK
    } from '../subworkflows/local/callatacpeak' addParams(
        options: getSubWorkFlowParam(modules, [
            'pairtools_select_short', 'merge_reads', 'shift_reads',
            'macs2_atac', 'dump_reads_per_group', 'dump_reads_per_sample',
            'merge_peak', 'atacqc', 'bedtools_genomecov_per_group',
            'bedtools_genomecov_per_sample', 'bedtools_sort_per_group',
            'bedtools_sort_per_sample', 'ucsc_bedclip',
            'ucsc_bedgraphtobigwig_per_group',
            'ucsc_bedgraphtobigwig_per_sample']))
include { R1_PEAK
    } from '../subworkflows/local/calldistalpeak' addParams(
        options: getSubWorkFlowParam(modules, [
            'merge_r1reads', 'r1reads', 'macs2_callr1peak',
            'dump_r1_reads_per_group', 'dump_r1_reads_per_sample',
            'merge_r1peak', 'r1qc', 'bedtools_genomecov_per_group',
            'bedtools_genomecov_per_sample', 'bedtools_sort_per_group',
            'bedtools_sort_per_sample', 'ucsc_bedclip',
            'ucsc_bedgraphtobigwig_per_r1_group',
            'ucsc_bedgraphtobigwig_per_r1_sample']))
include { HI_PEAK
    } from '../subworkflows/local/hipeak' addParams(
        options: getSubWorkFlowParam(modules, [
            'parepare_counts', 'call_hipeak', 'assign_type',
            'diff_hipeak', 'chippeakanno_hipeak',
            'chippeakanno_diffhipeak',
            'pair2bam']))
include { MAPS_MULTIENZYME
    } from '../subworkflows/local/multienzyme'   addParams(
        options: getSubWorkFlowParam(modules, [
            'maps_cut', 'maps_fend', 'genmap_index',
            'genmap_mappability', 'ucsc_wigtobigwig',
            'maps_mapability', 'maps_merge',
            'maps_feature', 'ensembl_ucsc_convert']))
include { MAPS_PEAK
    } from '../subworkflows/local/maps_peak' addParams(
        options: getSubWorkFlowParam(modules, [
            'maps_maps', 'maps_callpeak', 'maps_stats', 'maps_reformat']))
include { RUN_CIRCOS
    } from '../subworkflows/local/circos' addParams(
        options: getSubWorkFlowParam(modules, ['circos_prepare', 'circos']))
/*
================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
================================================================================
*/

def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ?
                        Utils.joinModuleArgs(
                            ["--title \"$params.multiqc_title\""]) : ''

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC
    } from '../modules/nf-core/modules/fastqc/main'  addParams(
        options: modules['fastqc'] )
include { CUTADAPT
    } from '../modules/nf-core/modules/cutadapt/main' addParams(
        options: getParam(modules, 'cutadapt'))
include { BWA_MEM
    } from '../modules/nf-core/modules/bwa/mem/main'  addParams(
        options: getParam(modules, 'bwa_mem'))
include { SAMTOOLS_MERGE
    } from '../modules/nf-core/modules/samtools/merge/main'  addParams(
        options: getParam(modules, 'samtools_merge'))
include { MULTIQC
    } from '../modules/nf-core/modules/multiqc/main' addParams(
        options: multiqc_options   )
include { CUSTOM_DUMPSOFTWAREVERSIONS
    } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main' addParams(
        options: [publish_files : ['_versions.yml':'']] )

/*
================================================================================
    RUN MAIN WORKFLOW
================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

// Parse input
ch_fastq = ch_input.map{
    row ->
        if(!row.group) { exit 1, 'Input samplesheet must contain 'group' column!' }
        if(!row.replicate) { exit 1, 'Input samplesheet must contain 'replicate' column!' }
        if(!row.fastq_1) { exit 1, 'Input samplesheet must contain 'fastq_1' column!' }
        if(!row.fastq_2) { exit 1, 'Input samplesheet must contain 'fastq_2' column!' }
        if(row.id) { exit 1, 'Input samplesheet can not contain 'id' column!' }
        fastq1 = file(row.remove("fastq_1"), checkIfExists: true)
        fastq2 = file(row.remove("fastq_2"), checkIfExists: true)
        meta = row
        meta.id = row.group + "_REP" + row.replicate
        [meta.id, meta, [fastq1, fastq2]]
}
// rename the input if there are technique duplicates
ch_fastq.groupTuple(by:[0])
        .map{
            id, meta, fq ->
                meta.eachWithIndex{
                    entry, index ->
                        entry.id = entry.id + "_T" + index
                        entry
            }
            [id, meta, fq]
        }.transpose()
        .map{[it[1], it[2]]}
        .set{ ch_reads }

//ch_reads.view()
cool_bin = Channel.fromList(params.cool_bin.tokenize('_'))

workflow HICAR {

    ch_software_versions = Channel.empty()
    ch_multiqc_files = Channel.from(ch_multiqc_config)

    //
    // check the input fastq files are correct and produce checksum for GEO submission
    //
    CHECKSUMS( ch_reads )
    ch_software_versions = ch_software_versions.mix(CHECKSUMS.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: Prepare genome
    //
    PREPARE_GENOME()
    ch_software_versions = ch_software_versions.mix(PREPARE_GENOME.out.versions.ifEmpty(null))

    //
    // MODULE: Run FastQC
    //
    if(!params.skip_fastqc){
        FASTQC (
            ch_reads
        )
        ch_software_versions = ch_software_versions.mix(FASTQC.out.versions.first().ifEmpty(null))
    }

    //
    // MODULE: trimming
    //
    if(!params.skip_cutadapt){
        CUTADAPT(
            ch_reads
        )
        ch_software_versions = ch_software_versions.mix(CUTADAPT.out.versions.ifEmpty(null))
        reads4mapping = CUTADAPT.out.reads
        ch_multiqc_files = ch_multiqc_files.mix(CUTADAPT.out.log.collect{it[1]}.ifEmpty([]))
    }else{
        reads4mapping = ch_reads
    }

    //
    // MODULE: mapping
    //
    BWA_MEM(
        reads4mapping,
        PREPARE_GENOME.out.bwa_index
    )
    ch_software_versions = ch_software_versions.mix(BWA_MEM.out.versions.ifEmpty(null))

    //
    // Pool the technique replicates
    //
    BWA_MEM.out.bam
                .map{
                    meta, bam ->
                        meta.id = meta.group + "_REP" + meta.replicate
                        [meta.id, meta, bam]
                }
                .groupTuple(by: [0])
                .map{[it[1][0], it[2].flatten()]}
                .set{ mapped_bam }
    //mapped_bam.view()//no branch to multiple and single, need to rename the bam files
    SAMTOOLS_MERGE(mapped_bam, [])
    ch_software_versions = ch_software_versions.mix(SAMTOOLS_MERGE.out.versions.ifEmpty(null))

    //
    // MODULE: mapping stats
    //
    BAM_STAT(SAMTOOLS_MERGE.out.bam)
    ch_software_versions = ch_software_versions.mix(BAM_STAT.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: filter reads, output pair (like hic pair), raw (pair), and stats
    //
    PAIRTOOLS_PAIRE(
        SAMTOOLS_MERGE.out.bam,
        PREPARE_GENOME.out.chrom_sizes,
        PREPARE_GENOME.out.digest_genome
    )
    ch_software_versions = ch_software_versions.mix(PAIRTOOLS_PAIRE.out.versions.ifEmpty(null))

    //
    // combine bin_size and create cooler file, and dump long_bedpe
    //
    cool_bin.combine(PAIRTOOLS_PAIRE.out.pair)
            .map{bin, meta, pair, px -> [meta, bin, pair, px]}
            .set{cool_input}
    COOLER(
        cool_input,
        PREPARE_GENOME.out.chrom_sizes,
        params.juicer_jvm_params,
        ch_juicer_tools
    )
    ch_software_versions = ch_software_versions.mix(COOLER.out.versions.ifEmpty(null))

    //
    // calling ATAC peaks, output ATAC narrowPeak and reads in peak
    //
    ATAC_PEAK(
        PAIRTOOLS_PAIRE.out.validpair,
        PREPARE_GENOME.out.chrom_sizes,
        PREPARE_GENOME.out.gsize,
        PREPARE_GENOME.out.gtf
    )
    ch_software_versions = ch_software_versions.mix(ATAC_PEAK.out.versions.ifEmpty(null))

    //
    // calling distal peaks: [ meta, bin_size, path(macs2), path(long_bedpe), path(short_bed), path(background) ]
    //
    background = MAPS_MULTIENZYME(PREPARE_GENOME.out.fasta,
                                    cool_bin,
                                    PREPARE_GENOME.out.chrom_sizes,
                                    ch_merge_map_py_source,
                                    ch_feature_frag2bin_source).bin_feature
    ch_software_versions = ch_software_versions.mix(MAPS_MULTIENZYME.out.versions.ifEmpty(null))
    reads_peak   = ATAC_PEAK.out.reads
                            .map{ meta, reads ->
                                    [meta.id, reads]} // here id is group
                            .combine(ATAC_PEAK.out.mergedpeak)// group, reads, peaks
                            .cross(COOLER.out.bedpe.map{[it[0].id, it[0].bin, it[1]]})// group, bin, bedpe
                            .map{ short_bed, long_bedpe -> //[bin_size, group, macs2, long_bedpe, short_bed]
                                    [long_bedpe[1], short_bed[0], short_bed[2], long_bedpe[2], short_bed[1]]}
    background.cross(reads_peak)
                .map{ background, reads -> //[group, bin_size, macs2, long_bedpe, short_bed, background]
                        [[id:reads[1]], background[0], reads[2], reads[3], reads[4], background[1]]}
                .set{ maps_input }
    MAPS_PEAK(maps_input, ch_make_maps_runfile_source)
    ch_software_versions = ch_software_versions.mix(MAPS_PEAK.out.versions.ifEmpty(null))

    MAPS_PEAK.out.peak.map{[it[0].id+'.'+it[1]+'.contacts',
                            getPublishedFolder( modules,
                                                'maps_reformat',
                                                [:])+it[2].name]}
        .mix(ATAC_PEAK.out
                    .bws.map{[it[0].id+"_R2",
                        getPublishedFolder( modules,
                                            'ucsc_bedgraphtobigwig_per_group',
                                            [:])+it[1].name]})
        .set{ch_trackfiles} // collect track files for igv

    //
    // calling R1 peaks, output R1 narrowPeak and reads in peak
    //
    if(params.high_resolution_R1){
        R1_PEAK(
            PAIRTOOLS_PAIRE.out.distalpair,
            PREPARE_GENOME.out.chrom_sizes,
            PREPARE_GENOME.out.gsize,
            PREPARE_GENOME.out.gtf
        )
        ch_software_versions = ch_software_versions.mix(R1_PEAK.out.versions.ifEmpty(null))
        ch_trackfiles = ch_trackfiles.mix(
            R1_PEAK.out.bws.map{[it[0].id+"_R1",
                getPublishedFolder(modules,
                    'ucsc_bedgraphtobigwig_per_r1_group', [:])+it[1].name]})

        // merge ATAC_PEAK with R1_PEAK by group id
        distalpair = PAIRTOOLS_PAIRE.out.hdf5.map{meta, bed -> [meta.group, bed]}
                                            .groupTuple()
        grouped_reads_peak = ATAC_PEAK.out.peak.map{[it[0].id, it[1]]}
                                .join(R1_PEAK.out.peak.map{[it[0].id, it[1]]})
                                .join(distalpair)
                                .map{[[id:it[0]], it[1], it[2], it[3]]}
        HI_PEAK(
            grouped_reads_peak,
            PREPARE_GENOME.out.gtf,
            PREPARE_GENOME.out.fasta,
            PREPARE_GENOME.out.digest_genome,
            MAPS_MULTIENZYME.out.mappability,
            params.skip_peak_annotation,
            params.skip_diff_analysis
        )
        ch_software_versions = ch_software_versions.mix(HI_PEAK.out.versions.ifEmpty(null))
        ch_trackfiles = ch_trackfiles.mix(
            HI_PEAK.out.bedpe
                    .map{[it[0].id+"_HiPeak",
                        getPublishedFolder( modules,
                                            'assign_type',
                                            [:])+it[1].name]})

        RUN_CIRCOS(
            HI_PEAK.out.bedpe,
            PREPARE_GENOME.out.gtf,
            PREPARE_GENOME.out.chrom_sizes,
            PREPARE_GENOME.out.ucscname,
            ch_circos_config
        )
        ch_software_versions = ch_software_versions.mix(RUN_CIRCOS.out.versions.ifEmpty(null))
    }

    //
    // Create igv index.html file
    //
    ch_trackfiles.collect{it.join('\t')}
        .flatten()
        .collectFile(
            name     :'track_files.txt',
            storeDir :getPublishedFolder(modules, 'igv', params),
            newLine  : true, sort:{it[0]})
        .set{ igv_track_files }
    //igv_track_files.view()
    IGV(igv_track_files, PREPARE_GENOME.out.ucscname)

    //
    // Annotate the MAPS peak
    //
    if(!params.skip_peak_annotation){
        MAPS_PEAK.out.peak //[]
            .map{meta, bin_size, peak -> [bin_size, peak]}
            .filter{ it[1].readLines().size > 1 }
            .groupTuple()
            .set{ch_maps_anno}
        BIOC_CHIPPEAKANNO_MAPS(ch_maps_anno, PREPARE_GENOME.out.gtf)
        ch_software_versions = ch_software_versions.mix(BIOC_CHIPPEAKANNO_MAPS.out.versions.ifEmpty(null))
        if(params.virtual_4c){
            BIOC_CHIPPEAKANNO_MAPS.out.csv
                .mix(
                    COOLER.out.mcool
                        .map{
                                meta, mcool ->
                                    [meta.bin, mcool]}
                        .groupTuple())
                .groupTuple()
                .map{bin, df -> [bin, df[0], df[1]]}
                .set{ch_maps_trackviewer}
            //ch_maps_trackviewer.view()
            BIOC_TRACKVIEWER_MAPS(
                ch_maps_trackviewer,
                PAIRTOOLS_PAIRE.out.hdf5.collect{it[1]},
                PREPARE_GENOME.out.gtf,
                PREPARE_GENOME.out.chrom_sizes,
                PREPARE_GENOME.out.digest_genome)
            ch_software_versions = ch_software_versions.mix(BIOC_TRACKVIEWER_MAPS.out.versions.ifEmpty(null))
        }
    }

    //
    // Differential analysis
    //
    if(!params.skip_diff_analysis){
        MAPS_PEAK.out.peak //[]
            .map{meta, bin_size, peak -> [bin_size, peak]}
            .groupTuple()
            .cross(COOLER.out.samplebedpe.map{[it[0].bin, it[1]]}.groupTuple())
            .map{ peak, long_bedpe ->
                [peak[0], peak[1].flatten(), long_bedpe[1].flatten()] }//bin_size, meta, peak, long_bedpe
            .groupTuple()
            .map{[it[0], it[1].flatten().unique(), it[2].flatten()]}
            .filter{it[1].size > 1} // filter by the bedpe files. Single bedpe means single group, no need to do differential analysis
            .set{ch_diffhicar}
        //ch_diffhicar.view()
        if(ch_diffhicar){
            DIFFHICAR(ch_diffhicar)
            ch_software_versions = ch_software_versions.mix(DIFFHICAR.out.versions.ifEmpty(null))
            //annotation
            if(!params.skip_peak_annotation){
                BIOC_CHIPPEAKANNO(DIFFHICAR.out.diff, PREPARE_GENOME.out.gtf)
                ch_software_versions = ch_software_versions.mix(BIOC_CHIPPEAKANNO.out.versions.ifEmpty(null))
                if(PREPARE_GENOME.out.ucscname && !params.skip_enrichment){
                    BIOC_ENRICH(
                        BIOC_CHIPPEAKANNO.out.anno.filter{it.size()>0},
                        PREPARE_GENOME.out.ucscname)
                    ch_software_versions = ch_software_versions.mix(BIOC_ENRICH.out.versions.ifEmpty(null))
                }
                if(params.virtual_4c){
                    BIOC_CHIPPEAKANNO.out.csv
                        .mix(COOLER.out.mcool
                                .map{meta, mcool -> [meta.bin, mcool]}
                                .groupTuple())
                        .groupTuple()
                        .map{bin, df -> [bin, df[0], df[1]]}
                        .set{ch_trackviewer}
                    //ch_trackviewer.view()
                    BIOC_TRACKVIEWER(
                        ch_trackviewer,
                        PAIRTOOLS_PAIRE.out.hdf5.collect{it[1]},
                        PREPARE_GENOME.out.gtf,
                        PREPARE_GENOME.out.chrom_sizes,
                        PREPARE_GENOME.out.digest_genome)
                    ch_software_versions = ch_software_versions.mix(BIOC_TRACKVIEWER.out.versions.ifEmpty(null))
                }
            }
        }
    }

    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_software_versions.unique().collectFile()
    )

    if(!params.skip_multiqc){
        //
        // MODULE: MultiQC
        //
        workflow_summary    = WorkflowHicar.paramsSummaryMultiqc(workflow, summary_params)
        ch_workflow_summary = Channel.value(workflow_summary)

        ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.yml.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STAT.out.stats.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STAT.out.flagstat.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STAT.out.idxstats.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(PAIRTOOLS_PAIRE.out.stat.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(BIOC_CHIPPEAKANNO_MAPS.out.png.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(ATAC_PEAK.out.stats.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(MAPS_PEAK.out.stats.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(DIFFHICAR.out.stats.collect().ifEmpty([]))
        ch_multiqc_files
            .flatten()
            .map { it -> if (it) [ it.baseName, it ] }
            .groupTuple()
            .map { it[1][0] }
            .flatten()
            .collect()
            .set { ch_multiqc_files }
        MULTIQC (
            ch_multiqc_files.collect()
        )
        multiqc_report       = MULTIQC.out.report.toList()
        ch_software_versions = ch_software_versions.mix(MULTIQC.out.versions.ifEmpty(null))
    }
}

/*
================================================================================
    COMPLETION EMAIL AND SUMMARY
================================================================================
*/

workflow.onComplete {
    NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    NfcoreTemplate.summary(workflow, params, log)
}

/*
================================================================================
    THE END
================================================================================
*/
