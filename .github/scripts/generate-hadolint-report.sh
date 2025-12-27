#!/bin/bash
#
# Generates a formatted Hadolint report for the GitHub Actions Job Summary.
#
# Usage:
# ./generate-hadolint-report.sh <path-to-hadolint-report.txt>
#

# --- Variables ---
# The first argument to the script is the input file path.
INPUT_FILE=${1}
# GITHUB_STEP_SUMMARY is a special environment variable for writing to the Job Summary.
OUTPUT_FILE=${GITHUB_STEP_SUMMARY}


# --- Pre-flight Checks ---
# Exit gracefully if the report file is not found.
if [ ! -f "$INPUT_FILE" ]; then
    echo "## 🐳 Hadolint Dockerfile Linter Report" >> "$OUTPUT_FILE"
    echo "❌ **Error:** Report file '$INPUT_FILE' not found." >> "$OUTPUT_FILE"
    exit 1
fi


# --- Report Generation ---
echo "## 🐳 Hadolint Dockerfile Linter Report" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check if the report file has content (-s checks if file size is greater than zero).
if [[ -s "$INPUT_FILE" ]]; then
    echo "Found issues that need attention in your Dockerfile:" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    # Format the output as a code block for readability.
    echo '```' >> "$OUTPUT_FILE"
    cat "$INPUT_FILE" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
else
    # If the file is empty, no issues were found.
    echo "✅ **No issues found.** The Dockerfile follows best practices." >> "$OUTPUT_FILE"
fi