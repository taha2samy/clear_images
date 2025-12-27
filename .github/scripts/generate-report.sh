#!/bin/bash

INPUT_FILE=${1:-trivy-results.json}
OUTPUT_FILE=${GITHUB_STEP_SUMMARY:-/dev/stdout}

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File $INPUT_FILE not found."
    exit 1
fi

COUNT=$(jq 'if .Results then ([.Results[] | select(.Vulnerabilities) | .Vulnerabilities[]] | length) else 0 end' "$INPUT_FILE")

echo "## 🛡️ Security Scan Results" >> "$OUTPUT_FILE"
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