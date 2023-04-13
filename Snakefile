configfile: "config.yaml"

rule all:
    input:
        "plots/quals.svg"

rule download_data:
    output:
        "snakemake-tutorial-data.tar.gz"
    shell:
        """
        curl -L https://api.github.com/repos/snakemake/snakemake-tutorial-data/tarball -o snakemake-tutorial-data.tar.gz
        """

rule extract_fa:
    input:
        "snakemake-tutorial-data.tar.gz"
    output:
        "data/genome.fa"
    shell:
        """
        tar --wildcards -xf snakemake-tutorial-data.tar.gz --strip 1 "*/data/*.fa.*" &&
        tar --wildcards -xf snakemake-tutorial-data.tar.gz --strip 1 "*/data/*.fa"
        """

rule extract_fastq:
    input:
        tar_file=rules.download_data.output
    output:
        "data/samples/{sample}.fastq"
    shell:
        """
        tar --wildcards -xf snakemake-tutorial-data.tar.gz --strip 1 "*/data/samples/*.fastq"
        """
        
rule bwa_map:
    input:
        "data/genome.fa",
        "data/samples/{sample}.fastq"
    output:
        "mapped_reads/{sample}.bam"
    conda:
        "environment.yml"
    shell:
        "bwa mem {input} | samtools view -Sb - > {output}"

rule samtools_sort:
    input:
        "mapped_reads/{sample}.bam"
    output:
        "sorted_reads/{sample}.bam"
    conda:
        "environment.yml"
    shell:
        "samtools sort -T sorted_reads/{wildcards.sample} "
        "-O bam {input} > {output}"

rule samtools_index:
    input:
        "sorted_reads/{sample}.bam"
    output:
        "sorted_reads/{sample}.bam.bai"
    conda:
        "environment.yml"
    shell:
        "samtools index {input}"

rule bcftools_call:
    input:
        fa="data/genome.fa",
        bam=expand("sorted_reads/{sample}.bam", sample=config["samples"]),
        bai=expand("sorted_reads/{sample}.bam.bai", sample=config["samples"])
    output:
        "calls/all.vcf"
    conda:
        "environment.yml"
    shell:
        "bcftools mpileup -f {input.fa} {input.bam} | "
        "bcftools call -mv - > {output}"

rule plot_quals:
    input:
        "calls/all.vcf"
    output:
        "plots/quals.svg"
    conda:
        "environment.yml"
    script:
        "scripts/plot-quals.py"
