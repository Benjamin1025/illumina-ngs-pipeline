#!/bin/bash

echo "========================================================"
echo "        ILLUMINA PAIRED-END TRIMMING SCRIPT             "
echo "========================================================"

# 1. Ask user for inputs
read -p "1. Enter the sample ID (e.g., SRR957824): " RAW_INPUT
read -p "2. Enter the output folder name (Press Enter for default: trimmed_data): " OUTDIR
OUTDIR="${OUTDIR:-trimmed_data}"

# Strip suffixes in case the user typed the full filename (like SRR957824_1.fastq.gz)
SAMPLE=$(echo "$RAW_INPUT" | sed -E 's/_[12]\.fastq\.gz$//; s/\.fastq\.gz$//')

echo "--------------------------------------------------------"

# 2. Check if sample input was left blank
if [[ -z "$SAMPLE" ]]; then
    echo "❌ TRIMMING FAILED: You did not enter a sample name."
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

# 6. Check if TruSeq3-PE.fa is in the current directory; download if missing
ADAPTER="TruSeq3-PE.fa"
ADAPTER_URL="https://raw.githubusercontent.com/usadellab/Trimmomatic/main/adapters/TruSeq3-PE.fa"

if [[ -f "$ADAPTER" && -s "$ADAPTER" ]]; then
    echo "✔ Adapter file '$ADAPTER' found in current folder. Skipping download."
else
    echo "⚠ Adapter file '$ADAPTER' is missing in current folder. Downloading now..."
    if wget -q --show-progress -O "$ADAPTER" "$ADAPTER_URL" && [[ -s "$ADAPTER" ]]; then
        echo "✔ Successfully downloaded '$ADAPTER' into $(pwd)."
    else
        rm -f "$ADAPTER"
        echo "❌ TRIMMING FAILED: Could not download '$ADAPTER'."
        echo "   Reason: Internet connection failed or GitHub could not be reached."
        exit 1
    fi
fi

# 7. Ask user for Trimmomatic settings (Press Enter for defaults)
echo "--------------------------------------------------------"
echo "TRIMMOMATIC SETTINGS (Press [Enter] at any prompt to use the default):"
echo ""

read -p "3. Sliding window size in bases (Press Enter for default: 4): " WIN_SIZE
WIN_SIZE="${WIN_SIZE:-4}"

read -p "4. Phred quality score cutoff (Press Enter for default: 20): " QUAL_SCORE
QUAL_SCORE="${QUAL_SCORE:-20}"

read -p "5. Minimum read length to keep in bp (Press Enter for default: 36): " MIN_LEN
MIN_LEN="${MIN_LEN:-36}"

read -p "6. Cut bases off the 5' start of reads - HEADCROP (Press Enter for default: 0 / none): " HEAD_BASES
HEAD_BASES="${HEAD_BASES:-0}"

read -p "7. Cut reads to a fixed max length from 3' end - CROP (Press Enter for default: none): " CROP_LEN

# Validate that numbers entered are valid positive integers
if ! [[ "$WIN_SIZE" =~ ^[0-9]+$ && "$QUAL_SCORE" =~ ^[0-9]+$ && "$MIN_LEN" =~ ^[0-9]+$ && "$HEAD_BASES" =~ ^[0-9]+$ ]]; then
    echo "❌ TRIMMING FAILED: Window size, quality score, minimum length, and HEADCROP must be whole numbers."
    exit 1
fi

EXTRA_STEPS=""
if [[ -n "$CROP_LEN" ]]; then
    if ! [[ "$CROP_LEN" =~ ^[0-9]+$ ]]; then
        echo "❌ TRIMMING FAILED: CROP length must be a whole number."
        exit 1
    elif [[ "$CROP_LEN" -gt 0 ]]; then
        EXTRA_STEPS="$EXTRA_STEPS CROP:${CROP_LEN}"
    fi
fi

if [[ "$HEAD_BASES" -gt 0 ]]; then
    EXTRA_STEPS="$EXTRA_STEPS HEADCROP:${HEAD_BASES}"
fi

# 8. Create output folder and check for permission errors
if ! mkdir -p "$OUTDIR" 2>/dev/null; then
    echo "❌ TRIMMING FAILED: Could not create output folder '$OUTDIR'."
    echo "   Reason: Permission denied or invalid folder path."
    exit 1
fi

echo "--------------------------------------------------------"
echo "✔ Forward read found : $FWD_READ"
echo "✔ Reverse read found : $REV_READ"
echo "✔ Adapter file       : $ADAPTER"
echo "✔ Trimming settings  : SLIDINGWINDOW:${WIN_SIZE}:${QUAL_SCORE} | MINLEN:${MIN_LEN}${EXTRA_STEPS}"
echo "✔ Output directory   : $OUTDIR/"
echo "--------------------------------------------------------"
echo "Running TrimmomaticPE now... Please wait."
echo ""

# 9. Run TrimmomaticPE and capture any runtime errors
ERROR_LOG=$(mktemp)

if TrimmomaticPE -threads 4 -phred33 \
    "$FWD_READ" "$REV_READ" \
    "${OUTDIR}/${SAMPLE}_1_paired.fastq.gz" "${OUTDIR}/${SAMPLE}_1_unpaired.fastq.gz" \
    "${OUTDIR}/${SAMPLE}_2_paired.fastq.gz" "${OUTDIR}/${SAMPLE}_2_unpaired.fastq.gz" \
    "ILLUMINACLIP:${ADAPTER}:2:30:10" \
    $EXTRA_STEPS \
    "SLIDINGWINDOW:${WIN_SIZE}:${QUAL_SCORE}" \
    "MINLEN:${MIN_LEN}" 2> >(tee "$ERROR_LOG" >&2); then

    # Catch Java exceptions that do not trigger a non-zero exit code
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
