# Automated Illumina Paired-End QC, Trimming & Alignment Pipeline

Interactive Linux Bash scripts automating read preprocessing (`TrimmomaticPE`) and reference genome alignment (`BWA-MEM` and `SAMtools`) for Illumina paired-end sequencing data.

### Files in this Project
* **`trim_reads.sh`**: Interactive script that checks for missing FASTQ files and trims adapters and low-quality 3' bases using `TrimmomaticPE`.
* **`align_pipeline.sh`**: Interactive script that indexes the reference genome (`bwa index`), aligns paired-end reads (`bwa mem`), sorts and indexes BAM files (`samtools`), and generates alignment statistics (`samtools flagstat`).

### Dataset Tested
* **Reads:** *Escherichia coli* Illumina paired-end reads (`SRR957824`) checked with `FastQC`.
* **Reference Genome:** *E. coli* K-12 MG1655 (`ecoli_ref.fasta`).
