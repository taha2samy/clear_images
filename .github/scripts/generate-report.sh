#!/bin/bash
# Usage: ./generate-report.sh <input-file> <service-name>

INPUT_FILE=${1}
SERVICE_NAME=${2:-"Service"}
OUTPUT_FILE=${GITHUB_STEP_SUMMARY}

if [ ! -f "$INPUT_FILE" ]; then
    echo "### 🛡️ Trivy Scan Results for ${SERVICE_NAME}" >> "$OUTPUT_FILE"
    echo "❌ **Error:** Report file '$INPUT_FILE' not found." >> "$OUTPUT_FILE"
    exit 1
fi

COUNT=$(jq 'if .Results then ([.Results[] | select(.Vulnerabilities) | .Vulnerabilities[]] | length) else 0 end' "$INPUT_FILE")

echo "### 🛡️ Trivy Scan Results for ${SERVICE_NAME}" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [ "$COUNT" -eq "0" ]; then
    echo "✅ **No vulnerabilities found.** The image is clean." >> "$OUTPUT_FILE"
else
    echo "Found **$COUNT** vulnerabilities." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "| Severity | Package | Vulnerability ID | Installed | Fixed In | Link |" >> "$OUTPUT_FILE"
    echo "| :---: | :--- | :--- | :--- | :--- | :---: |" >> "$OUTPUT_FILE"

    jq -r '
      .Results[] | select(.Vulnerabilities) | .Vulnerabilities[] |
      [
        (if .Severity == "CRITICAL" then "🔴 CRITICAL"
         elif .Severity == "HIGH" then "🟠 HIGH"
         elif .Severity == "MEDIUM" then "🟡 MEDIUM"
         else "🔵 LOW" end),
        .PkgName,
        .VulnerabilityID,
        .InstalledVersion,
        (.FixedVersion // "N/A"),
        "[View](" + .PrimaryURL + ")"
      ] | join(" | ")
    ' "$INPUT_FILE" | sed 's/^/| /' | sed 's/$/ |/' >> "$OUTPUT_FILE"
fi