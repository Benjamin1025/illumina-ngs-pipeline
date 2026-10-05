# Automated Illumina Paired-End QC, Trimming & Alignment Pipeline

Interactive Linux Bash scripts automating read preprocessing (`TrimmomaticPE`) and reference genome alignment (`BWA-MEM` and `SAMtools`) for Illumina paired-end whole-genome sequencing (WGS) data.

---

## Before You Begin

Before running these scripts, make sure to download and install the required bioinformatics tools (`FastQC`, `Trimmomatic`, `BWA`, and `SAMtools`) and the Illumina adapter file on your Linux/Ubuntu system.

### 1. Install Required Tools (Ubuntu / Debian)
Open your terminal and run:
```bash
sudo apt update
sudo apt install -y fastqc trimmomatic bwa samtools wget gzip
```

*(Note: On Ubuntu, installing `trimmomatic` via `apt` provides the case-sensitive command `TrimmomaticPE` for paired-end reads and `TrimmomaticSE` for single-end reads.)*

### 2. Verify Your Installations
Confirm that each tool is installed properly:
```bash
fastqc --version
TrimmomaticPE -version
bwa 2>&1 | head -n 5
samtools --version
```

### 3. Download the Illumina Adapter File (`TruSeq3-PE.fa`)
If `TruSeq3-PE.fa` is not already in `/usr/share/trimmomatic/`, download it into your working directory or home folder using `wget`:
```bash
wget [https://raw.githubusercontent.com/usadellab/Trimmomatic/main/adapters/TruSeq3-PE.fa](https://raw.githubusercontent.com/usadellab/Trimmomatic/main/adapters/TruSeq3-PE.fa)
```

---

##  Pipeline Scripts Overview

### 1. `trim_reads.sh` (Interactive Quality, Adapter & Position Trimming)
* Interactive CLI wrapper for `TrimmomaticPE` featuring customizable user prompts with smart defaults:
  * **Sliding Window Size (`SLIDINGWINDOW`):** Default `4` bases
  * **Phred Quality Score Cutoff:** Default `20`
  * **Minimum Read Length (`MINLEN`):** Default `36` bp
  * **Optional 5' & 3' Cropping (`HEADCROP` / `CROP`):** User-defined base trimming
* Performs automated pre-flight validation for missing or empty (`0 byte`) forward and reverse FASTQ files, validates numeric inputs, automatically locates `TruSeq3-PE.fa`, and catches Java runtime exceptions.

### 2. `align_pipeline.sh` (Automated BWA-MEM Alignment & SAMtools Processing)
* **Smart Index Detection:** Automatically checks the reference genome directory for existing BWA index files (`.amb`, `.ann`, `.bwt`, `.pac`, `.sa`). Runs `bwa index` if any are missing, or skips indexing if they already exist.
* **Flexible Input Selection:** Supports aligning either trimmed paired-end reads (`_paired.fastq.gz`) or raw untrimmed reads (`_1.fastq.gz` and `_2.fastq.gz`).
* **Automated SAM/BAM Workflow:**
  1. Maps paired-end reads to the reference genome using `bwa mem`.
  2. Converts and coordinate-sorts alignments into binary `.bam` format using `samtools sort`.
  3. Indexes the sorted `.bam` file (`samtools index`) to generate the `.bai` file.
  4. Calculates and saves alignment summary statistics (`samtools flagstat`).

---

## How to Run the Pipeline

### Step 1: Make the Scripts Executable
```bash
chmod +x trim_reads.sh align_pipeline.sh
```

### Step 2: Run Quality & Adapter Trimming
```bash
./trim_reads.sh
```

### Step 3: Check Trimmed Paired Reads with FastQC
```bash
mkdir -p qc_trimmed
fastqc trimmed_data/*_paired.fastq.gz -o qc_trimmed/
```

### Step 4: Run Reference Genome Alignment & SAMtools Processing
```bash
./align_pipeline.sh
```

---

##  Example Dataset Used for Validation

* **Sequencing Reads:** *Escherichia coli* Illumina paired-end WGS reads (NCBI SRA: `SRR957824`, 211,029 read pairs, 150 bp)
* **Reference Genome:** *Escherichia coli* str. K-12 substr. MG1655 (NCBI RefSeq: `GCF_000005845.2`)

To download and decompress the *E. coli* reference genome (~1.3 MB download):
```bash
mkdir -p ecoli_ref_genome
wget -O - [https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz](https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz) | gunzip -c > ecoli_ref_genome/ecoli_ref.fasta
```
