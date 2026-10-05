#!/bin/bash

echo "========================================================"
echo "     ILLUMINA BWA & SAMTOOLS ALIGNMENT PIPELINE         "
echo "========================================================"
echo "Tip: You can press the [Tab] key to auto-complete paths!"
echo "--------------------------------------------------------"

# 1. Check if BWA and SAMtools are installed
if ! command -v bwa &> /dev/null; then
    echo "❌ ALIGNMENT FAILED: 'bwa' is not installed."
    echo "   Fix: Run 'sudo apt update && sudo apt install -y bwa'"
    exit 1
fi

if ! command -v samtools &> /dev/null; then
    echo "❌ ALIGNMENT FAILED: 'samtools' is not installed."
    echo "   Fix: Run 'sudo apt update && sudo apt install -y samtools'"
    exit 1
fi

# ========================================================
# 2. REFERENCE GENOME & AUTOMATIC INDEX CHECK
# ========================================================
read -e -p "1. Enter the directory of your reference genome (e.g., ~/data/ecoli_ref_genome): " REF_DIR
REF_DIR="${REF_DIR/#\~/$HOME}"
REF_DIR="${REF_DIR%/}"

if [[ -z "$REF_DIR" || ! -d "$REF_DIR" ]]; then
    echo "❌ ALIGNMENT FAILED: Reference directory '$REF_DIR' does not exist!"
    echo "   Current working directory: $(pwd)"
    exit 1
fi

echo "   Files found in $REF_DIR:"
ls "$REF_DIR" | grep -E '\.(fasta|fa|fna)$' | sed 's/^/     - /'

read -e -p "2. Enter the reference genome filename (default: ecoli_ref.fasta): " REF_NAME
REF_NAME="${REF_NAME:-ecoli_ref.fasta}"
REF_FILE="${REF_DIR}/${REF_NAME}"

if [[ ! -f "$REF_FILE" ]]; then
    echo "❌ ALIGNMENT FAILED: Reference genome file '$REF_FILE' is missing!"
    exit 1
elif [[ ! -s "$REF_FILE" ]]; then
    echo "❌ ALIGNMENT FAILED: Reference genome file '$REF_FILE' is empty (0 bytes)!"
    exit 1
fi

# Check if all 5 BWA index files (.amb, .ann, .bwt, .pac, .sa) already exist
echo "--------------------------------------------------------"
if [[ -f "${REF_FILE}.amb" && -f "${REF_FILE}.ann" && -f "${REF_FILE}.bwt" && -f "${REF_FILE}.pac" && -f "${REF_FILE}.sa" ]]; then
    echo "✔ BWA index files already exist for '$REF_NAME'. Skipping indexing step!"
else
    echo "⚙ BWA index files not found. Indexing '$REF_FILE' now..."
    if ! bwa index "$REF_FILE"; then
        echo "❌ ALIGNMENT FAILED: 'bwa index' encountered an error while indexing '$REF_FILE'."
        exit 1
    fi
    echo "✔ Indexing completed successfully!"
fi
echo "--------------------------------------------------------"

# ========================================================
# 3. CHOOSE TRIMMED VS. UNTRIMMED READS & INPUT DIRECTORY
# ========================================================
echo "Which type of FASTQ reads do you want to align?"
echo "  [1] Trimmed reads (e.g., SAMPLE_1_paired.fastq.gz & SAMPLE_2_paired.fastq.gz)"
echo "  [2] Untrimmed raw reads (if FastQC quality is already good: SAMPLE_1.fastq.gz & SAMPLE_2.fastq.gz)"
read -p "Select 1 or 2 (default: 1): " READ_TYPE
READ_TYPE="${READ_TYPE:-1}"

if [[ "$READ_TYPE" != "1" && "$READ_TYPE" != "2" ]]; then
    echo "❌ ALIGNMENT FAILED: Invalid selection '$READ_TYPE'. Please enter 1 or 2."
    exit 1
fi

read -e -p "3. Enter the directory containing your FASTQ files (e.g., trimmed_data or .): " READ_DIR
READ_DIR="${READ_DIR/#\~/$HOME}"
READ_DIR="${READ_DIR%/}"

if [[ -z "$READ_DIR" || ! -d "$READ_DIR" ]]; then
    echo "❌ ALIGNMENT FAILED: Read directory '$READ_DIR' does not exist!"
    exit 1
fi

read -p "4. Enter the Sample ID (e.g., SRR957824): " RAW_SAMPLE
SAMPLE=$(echo "$RAW_SAMPLE" | sed -E 's/_[12](_paired|_unpaired)?\.fastq\.gz$//; s/\.fastq\.gz$//')

if [[ -z "$SAMPLE" ]]; then
    echo "❌ ALIGNMENT FAILED: You did not enter a Sample ID."
    exit 1
fi

if [[ "$READ_TYPE" == "1" ]]; then
    FWD_READ="${READ_DIR}/${SAMPLE}_1_paired.fastq.gz"
    REV_READ="${READ_DIR}/${SAMPLE}_2_paired.fastq.gz"
else
    FWD_READ="${READ_DIR}/${SAMPLE}_1.fastq.gz"
    REV_READ="${READ_DIR}/${SAMPLE}_2.fastq.gz"
fi

# Verify Forward and Reverse reads exist and are not empty
if [[ ! -f "$FWD_READ" ]]; then
    echo "❌ ALIGNMENT FAILED: Forward read '$FWD_READ' is missing!"
    echo "   Fix: Check that '$READ_DIR' is the right folder and '$SAMPLE' is spelled correctly."
    exit 1
elif [[ ! -s "$FWD_READ" ]]; then
    echo "❌ ALIGNMENT FAILED: Forward read '$FWD_READ' is empty (0 bytes)!"
    exit 1
fi

if [[ ! -f "$REV_READ" ]]; then
    echo "❌ ALIGNMENT FAILED: Reverse read '$REV_READ' is missing!"
    echo "   Fix: Found forward read, but its matching reverse read is not in '$READ_DIR'."
    exit 1
elif [[ ! -s "$REV_READ" ]]; then
    echo "❌ ALIGNMENT FAILED: Reverse read '$REV_READ' is empty (0 bytes)!"
    exit 1
fi

# ========================================================
# 4. OUTPUT DIRECTORIES & FILENAMES FOR SAM AND BAM
# ========================================================
echo "--------------------------------------------------------"
read -e -p "5. Enter the directory to save your .sam file (e.g., aligned_data): " SAM_DIR
SAM_DIR="${SAM_DIR/#\~/$HOME}"
SAM_DIR="${SAM_DIR%/}"

if [[ -z "$SAM_DIR" ]]; then
    echo "❌ ALIGNMENT FAILED: You did not enter an output directory for the .sam file."
    exit 1
fi

if ! mkdir -p "$SAM_DIR" 2>/dev/null; then
    echo "❌ ALIGNMENT FAILED: Could not create directory '$SAM_DIR' (Permission denied)."
    exit 1
fi

read -p "6. Enter the name for your .sam file (default: ${SAMPLE}.sam): " SAM_NAME
SAM_NAME="${SAM_NAME:-${SAMPLE}.sam}"
[[ "$SAM_NAME" != *.sam ]] && SAM_NAME="${SAM_NAME}.sam"
SAM_PATH="${SAM_DIR}/${SAM_NAME}"

read -e -p "7. Enter the directory to save your sorted .bam files (Press Enter to use '$SAM_DIR'): " BAM_DIR
BAM_DIR="${BAM_DIR:-$SAM_DIR}"
BAM_DIR="${BAM_DIR/#\~/$HOME}"
BAM_DIR="${BAM_DIR%/}"

if ! mkdir -p "$BAM_DIR" 2>/dev/null; then
    echo "❌ ALIGNMENT FAILED: Could not create directory '$BAM_DIR' (Permission denied)."
    exit 1
fi

DEFAULT_BAM="${SAM_NAME%.sam}_sorted.bam"
read -p "8. Enter the name for your sorted .bam file (default: $DEFAULT_BAM): " BAM_NAME
BAM_NAME="${BAM_NAME:-$DEFAULT_BAM}"
[[ "$BAM_NAME" != *.bam ]] && BAM_NAME="${BAM_NAME}.bam"
BAM_PATH="${BAM_DIR}/${BAM_NAME}"

# ========================================================
# 5. RUN BWA MEM ALIGNMENT
# ========================================================
echo "========================================================"
echo "✔ Reference Genome : $REF_FILE"
echo "✔ Forward Read     : $FWD_READ"
echo "✔ Reverse Read     : $REV_READ"
echo "✔ Output SAM File  : $SAM_PATH"
echo "✔ Output BAM File  : $BAM_PATH"
echo "========================================================"
echo "⏳ Step 1/4: Running 'bwa mem' alignment..."

BWA_ERR=$(mktemp)
if ! bwa mem -t 4 "$REF_FILE" "$FWD_READ" "$REV_READ" > "$SAM_PATH" 2> >(tee "$BWA_ERR" >&2); then
    echo "❌ ALIGNMENT FAILED DURING 'bwa mem'!"
    echo "   Reason: BWA exited with an error (corrupted FASTQ file or out of disk space)."
    cat "$BWA_ERR"
    rm -f "$BWA_ERR"
    exit 1
fi
rm -f "$BWA_ERR"

if [[ ! -s "$SAM_PATH" ]]; then
    echo "❌ ALIGNMENT FAILED: '$SAM_PATH' was created but is empty (0 bytes)!"
    exit 1
fi
echo "✔ Step 1/4 Complete: SAM file saved to $SAM_PATH"

# ========================================================
# 6. RUN SAMTOOLS (SORT, INDEX, FLAGSTAT)
# ========================================================
echo ""
echo "⏳ Step 2/4: Converting SAM to coordinate-sorted BAM ('samtools sort')..."
if ! samtools sort -@ 4 -o "$BAM_PATH" "$SAM_PATH"; then
    echo "❌ FAILED DURING 'samtools sort'!"
    echo "   Reason: Could not sort '$SAM_PATH' (check available disk space)."
    exit 1
fi
echo "✔ Step 2/4 Complete: Sorted BAM saved to $BAM_PATH"

echo ""
echo "⏳ Step 3/4: Indexing sorted BAM file ('samtools index')..."
if ! samtools index "$BAM_PATH"; then
    echo "❌ FAILED DURING 'samtools index'!"
    echo "   Reason: Could not create .bai index for '$BAM_PATH'."
    exit 1
fi
echo "✔ Step 3/4 Complete: BAM index saved to ${BAM_PATH}.bai"

echo ""
echo "⏳ Step 4/4: Calculating alignment statistics ('samtools flagstat')..."
STATS_FILE="${BAM_PATH%.bam}_flagstat.txt"
echo "--------------------------------------------------------"
if ! samtools flagstat "$BAM_PATH" | tee "$STATS_FILE"; then
    echo "❌ FAILED DURING 'samtools flagstat'!"
    exit 1
fi
echo "--------------------------------------------------------"
echo "✔ Step 4/4 Complete: Alignment stats saved to $STATS_FILE"

# ========================================================
# 7. OPTIONAL CLEANUP OF RAW .SAM FILE
# ========================================================
echo ""
read -p "Do you want to delete the large uncompressed '$SAM_PATH' file to save disk space? (y/n, default: n): " DEL_SAM
if [[ "$DEL_SAM" =~ ^[Yy]$ ]]; then
    rm -f "$SAM_PATH"
    echo "🗑️  Deleted '$SAM_PATH'."
fi

echo ""
echo "✅ ALL STEPS COMPLETED SUCCESSFULLY!"
echo "Your final aligned files:"
ls -lh "$BAM_PATH" "${BAM_PATH}.bai" "$STATS_FILE"
