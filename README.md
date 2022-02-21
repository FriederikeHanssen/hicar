# ![nf-core/hicar](docs/images/nf-core-hicar_logo_light.png#gh-light-mode-only) ![nf-core/hicar](docs/images/nf-core-hicar_logo_dark.png#gh-dark-mode-only)

[![GitHub Actions CI Status](https://github.com/nf-core/hicar/workflows/nf-core%20CI/badge.svg)](https://github.com/nf-core/hicar/actions?query=workflow%3A%22nf-core+CI%22)
[![GitHub Actions Linting Status](https://github.com/nf-core/hicar/workflows/nf-core%20linting/badge.svg)](https://github.com/nf-core/hicar/actions?query=workflow%3A%22nf-core+linting%22)
[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/hicar/results)
[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.5618247-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.5618247)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.10.3-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23hicar-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/hicar)
[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)
[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/hicar** is a bioinformatics best-practice analysis pipeline for [HiC on Accessible Regulatory DNA (HiCAR)](https://doi.org/10.1101/2020.11.02.366062) data, a robust and sensitive assay for simultaneous measurement of chromatin accessibility and cis-regulatory chromatin contacts. Unlike the immunoprecipitation-based methods such as HiChIP, PlAC-seq and ChIA-PET, HiCAR does not require antibodies. HiCAR utilizes a Transposase-Accessible Chromatin assay to anchor the chromatin interactions. HiCAR is a tool to study chromatin interactions for low input samples and samples with no available antibodies.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources. The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/hicar/results).

## Pipeline summary

1. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Trim reads ([`cutadapt`](https://cutadapt.readthedocs.io/en/stable/))
3. Map reads ([`bwa mem`](http://bio-bwa.sourceforge.net/bwa.shtml))
4. Filter reads ([`pairtools`](https://pairtools.readthedocs.io/en/latest/))
5. Quality analysis ([`pairsqc`](https://github.com/4dn-dcic/pairsqc))
6. Call peaks for ATAC reads (R2 reads) ([`MACS2`](https://macs3-project.github.io/MACS/)) and/or call peaks for R1 reads.
7. Find TADs and loops ([`MAPS`](https://github.com/ijuric/MAPS))
8. Differential analysis ([`edgeR`](https://bioconductor.org/packages/edgeR/))
9. Annotation TADs and loops ([`ChIPpeakAnno`](https://bioconductor.org/packages/ChIPpeakAnno/))
10. Create cooler files ([`cooler`](https://cooler.readthedocs.io/en/latest/index.html), .hic files [`Juicer_tools`](https://github.com/aidenlab/juicer/wiki), and circos files [`circos`](http://circos.ca/)) for visualization.
11. Present QC for raw reads ([`MultiQC`](http://multiqc.info/))

![work flow of the pipeline](docs/images/workflow.svg)

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.10.3`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```console
    nextflow run nf-core/hicar -profile test,YOURPROFILE
    ```

    Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

    > * The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
    > * Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
    > * If you are using `singularity` and are persistently observing issues downloading Singularity images directly due to timeout or network issues, then you can use the `--singularity_pull_docker_container` parameter to pull and convert the Docker image instead. Alternatively, you can use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
    > * If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

    ```console
    nextflow run nf-core/hicar -profile <docker/singularity/podman/shifter/charliecloud/conda/institute> \
        --input samples.csv \   # Input data
        --qval_thresh 0.01 \    # Cut-off q-value for MACS2
        --genome GRCh38 \       # Genome Reference
        --mappability /path/mappability/bigWig/file  # Provide mappability to avoid memory intensive calculation
    ```

    Run it on cluster.

    First prepare a profile config file named as [profile.config](https://nf-co.re/hicar/usage) and a [samplesheet](https://nf-co.re/hicar/usage).
    Then run:

    ```console
    nextflow run nf-core/hicar -profile <docker/singularity/podman/shifter/charliecloud/conda/institute> -c profile.config
    ```

## Documentation

The nf-core/hicar pipeline comes with documentation about the pipeline [usage](https://nf-co.re/hicar/usage), [parameters](https://nf-co.re/hicar/parameters) and [output](https://nf-co.re/hicar/output).

## Credits

nf-core/hicar was originally written by Jianhong Ou, [Yu Xiang](https://github.com/yuxuth), and Yarui Diao.

We thank the following people for their extensive assistance in the development of this pipeline: Phil Ewels, Mahesh Binzer-Panchal and Friederike Hanssen.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#hicar` channel](https://nfcore.slack.com/channels/hicar) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use  nf-core/hicar for your analysis, please cite it using the following doi: [10.5281/zenodo.5618247](https://doi.org/10.5281/zenodo.5618247)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
