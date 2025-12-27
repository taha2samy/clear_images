#!/bin/bash
# Usage: ./generate-hadolint-report.sh <input-file> <service-name>

INPUT_FILE=${1}
SERVICE_NAME=${2:-"Service"} # Default to "Service" if not provided
OUTPUT_FILE=${GITHUB_STEP_SUMMARY}

if [ ! -f "$INPUT_FILE" ]; then
    echo "### 🐳 Hadolint Report for ${SERVICE_NAME}" >> "$OUTPUT_FILE"
    echo "❌ **Error:** Report file '$INPUT_FILE' not found." >> "$OUTPUT_FILE"
    exit 1
fi

echo "### 🐳 Hadolint Report for ${SERVICE_NAME}" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [[ -s "$INPUT_FILE" ]]; then
    echo "Found issues that need attention in your Dockerfile:" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
    cat "$INPUT_FILE" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
else
    echo "✅ **No issues found.** The Dockerfile follows best practices." >> "$OUTPUT_FILE"
fi