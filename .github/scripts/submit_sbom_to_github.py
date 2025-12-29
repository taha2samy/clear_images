#!/usr/bin/env python3
import json
import sys
import os
from datetime import datetime, timezone

def extract_purls_from_spdx(sbom_path):
    """Extract Package URLs from SPDX SBOM"""
    with open(sbom_path, 'r') as f:
        sbom = json.load(f)
    
    resolved = {}
    for pkg in sbom.get('packages', []):
        purl = None
        if 'externalRefs' in pkg:
            for ref in pkg['externalRefs']:
                if ref.get('referenceType') == 'purl':
                    purl = ref.get('referenceLocator')
                    break
        
        if purl:
            resolved[purl] = {
                "package_url": purl,
                "relationship": "direct"
            }
    
    return resolved

def build_snapshot(service_name, sbom_path, repo, run_id, sha, ref):
    """Build GitHub Dependency Submission API payload"""
    resolved = extract_purls_from_spdx(sbom_path)
    
    if not resolved:
        print(f"Warning: No PURLs found in {sbom_path}", file=sys.stderr)
        return None
    
    snapshot = {
        "version": 0,
        "job": {
            "correlator": f"sbom-{service_name}-CI-Pipeline",
            "id": run_id
        },
        "sha": sha,
        "ref": ref,
        "scanned": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        "detector": {
            "name": "syft-manual-submission",
            "version": "1.0.0",
            "url": f"https://github.com/{repo}"
        },
        "manifests": {
            service_name: {
                "name": service_name,
                "file": {
                    "source_location": f"/{service_name}/Dockerfile"
                },
                "resolved": resolved
            }
        }
    }
    
    return snapshot

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: submit_sbom_to_github.py <sbom-file> [service-name]", file=sys.stderr)
        sys.exit(1)
    
    sbom_path = sys.argv[1]
    service_name = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(os.path.basename(sbom_path))[0].replace('-sbom', '')
    
    repo = os.getenv('GITHUB_REPOSITORY', 'unknown/repo')
    run_id = os.getenv('GITHUB_RUN_ID', '0')
    sha = os.getenv('GITHUB_SHA', '')
    ref = os.getenv('GITHUB_REF', 'refs/heads/main')
    
    snapshot = build_snapshot(service_name, sbom_path, repo, run_id, sha, ref)
    
    if snapshot:
        print(json.dumps(snapshot, indent=2))
    else:
        sys.exit(1)
