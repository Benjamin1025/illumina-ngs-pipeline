#!/bin/bash

echo "========================================================"
echo "        ILLUMINA PAIRED-END TRIMMING SCRIPT             "
echo "========================================================"

# 1. Ask user for inputs
read -p "Enter the sample ID (e.g., SRR957824): " RAW_INPUT
read -p "Enter the output folder name (e.g., trimmed_data): " OUTDIR

# Strip suffixes in case the user typed the full filename (like SRR957824_1.fastq.gz)
SAMPLE=$(echo "$RAW_INPUT" | sed -E 's/_[12]\.fastq\.gz$//; s/\.fastq\.gz$//')

echo "--------------------------------------------------------"

# 2. Check if inputs were left blank
if [[ -z "$SAMPLE" ]]; then
    echo "❌ TRIMMING FAILED: You did not enter a sample name."
    exit 1
fi

if [[ -z "$OUTDIR" ]]; then
    echo "❌ TRIMMING FAILED: You did not enter an output folder name."
    exit 1
fi

# Define expected input files
FWD_READ="${SAMPLE}_1.fastq.gz"
REV_READ="${SAMPLE}_2.fastq.gz"

# 3. Check if TrimmomaticPE is installed
if ! command -v TrimmomaticPE &> /dev/null; then
    echo "❌ TRIMMING FAILED: 'TrimmomaticPE' is not installed or not in your PATH."
    echo "   Fix: Run 'sudo apt install trimmomatic'"
    exit 1
fi

# 4. Check if Forward Read exists and is not empty
if [[ ! -f "$FWD_READ" ]]; then
    echo "❌ TRIMMING FAILED: Forward read file '$FWD_READ' is missing!"
    echo "   Current folder: $(pwd)"
    echo "   Fix: Make sure you spelled the sample name right and are in the folder containing your .fastq.gz files."
    exit 1
elif [[ ! -s "$FWD_READ" ]]; then
    echo "❌ TRIMMING FAILED: Forward read file '$FWD_READ' exists, but the file is completely empty (0 bytes)."
    exit 1
fi

# 5. Check if Reverse Read exists and is not empty
if [[ ! -f "$REV_READ" ]]; then
    echo "❌ TRIMMING FAILED: Reverse read file '$REV_READ' is missing!"
    echo "   Current folder: $(pwd)"
    echo "   Fix: Found '$FWD_READ', but its paired reverse file '$REV_READ' is not in this folder."
    exit 1
elif [[ ! -s "$REV_READ" ]]; then
    echo "❌ TRIMMING FAILED: Reverse read file '$REV_READ' exists, but the file is completely empty (0 bytes)."
    exit 1
fi

# 6. Locate the TruSeq3-PE.fa adapter file automatically
if [[ -f "TruSeq3-PE.fa" ]]; then
    ADAPTER="TruSeq3-PE.fa"
elif [[ -f "$HOME/TruSeq3-PE.fa" ]]; then
    ADAPTER="$HOME/TruSeq3-PE.fa"
elif [[ -f "/usr/share/trimmomatic/TruSeq3-PE.fa" ]]; then
    ADAPTER="/usr/share/trimmomatic/TruSeq3-PE.fa"
else
    echo "❌ TRIMMING FAILED: Adapter file 'TruSeq3-PE.fa' could not be found."
    echo "   Checked: current folder, home folder (~), and /usr/share/trimmomatic/"
    echo "   Fix: Run 'wget https://raw.githubusercontent.com/usadellab/Trimmomatic/main/adapters/TruSeq3-PE.fa'"
    exit 1
fi

# 7. Create output folder and check for permission errors
if ! mkdir -p "$OUTDIR" 2>/dev/null; then
    echo "❌ TRIMMING FAILED: Could not create output folder '$OUTDIR'."
    echo "   Reason: Permission denied or invalid folder path."
    exit 1
fi

echo "✔ Forward read found : $FWD_READ"
echo "✔ Reverse read found : $REV_READ"
echo "✔ Adapter file found : $ADAPTER"
echo "✔ Output directory   : $OUTDIR/"
echo "--------------------------------------------------------"
echo "Running TrimmomaticPE now... Please wait."
echo ""

# 8. Run TrimmomaticPE and capture any runtime errors
ERROR_LOG=$(mktemp)

if TrimmomaticPE -threads 4 -phred33 \
    "$FWD_READ" "$REV_READ" \
    "${OUTDIR}/${SAMPLE}_1_paired.fastq.gz" "${OUTDIR}/${SAMPLE}_1_unpaired.fastq.gz" \
    "${OUTDIR}/${SAMPLE}_2_paired.fastq.gz" "${OUTDIR}/${SAMPLE}_2_unpaired.fastq.gz" \
    "ILLUMINACLIP:${ADAPTER}:2:30:10" \
    SLIDINGWINDOW:4:20 \
    MINLEN:36 2> >(tee "$ERROR_LOG" >&2); then

    # Trimmomatic sometimes prints Java exceptions without setting a non-zero exit code
    if grep -qi "Exception" "$ERROR_LOG"; then
        echo ""
        echo "❌ TRIMMING FAILED DURING EXECUTION!"
        echo "   Reason reported by Trimmomatic:"
        grep -i -E "Exception|Error" "$ERROR_LOG"
        rm -f "$ERROR_LOG"
        exit 1
    fi

    echo ""
    echo "✅ SUCCESS! Trimming completed without errors."
    echo "Your trimmed files are saved in: ${OUTDIR}/"
    ls -lh "${OUTDIR}/${SAMPLE}"*.fastq.gz
    rm -f "$ERROR_LOG"
else
    echo ""
    echo "❌ TRIMMING FAILED DURING EXECUTION!"
    echo "   Reason: Trimmomatic crashed (corrupted .fastq.gz file, out of disk space, or invalid parameters)."
    echo "   Detailed error log:"
    cat "$ERROR_LOG"
    rm -f "$ERROR_LOG"
    exit 1
fi
