import json
import glob
import datetime
import os
import sys

def merge_sboms():
    input_pattern = 'all-reports/*-sbom.spdx.json'
    output_file = 'all-reports/merged-sbom.spdx.json'
    repo_name = os.getenv('GITHUB_REPOSITORY', 'unknown/repository')

    merged = {
        'spdxVersion': 'SPDX-2.3',
        'dataLicense': 'CC0-1.0',
        'SPDXID': 'SPDXRef-DOCUMENT',
        'name': 'Merged-Project-SBOM',
        'documentNamespace': f'https://github.com/{repo_name}/merged-sbom',
        'creationInfo': {
            'creators': ['Tool: GitHub-Actions-Merge-Script'],
            'created': datetime.datetime.utcnow().isoformat() + 'Z'
        },
        'packages': [],
        'relationships': []
    }

    seen_pkg_ids = set()
    files = glob.glob(input_pattern)
    
    print(f"Found {len(files)} SBOM files to merge: {files}")

    if not files:
        print("Warning: No SBOM files found to merge.")
        return

    for file_path in files:
        print(f"Processing: {file_path}")
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                
                for pkg in data.get('packages', []):
                    pkg_id = pkg.get('SPDXID')
                    if pkg_id and pkg_id not in seen_pkg_ids:
                        merged['packages'].append(pkg)
                        seen_pkg_ids.add(pkg_id)
                
                for rel in data.get('relationships', []):
                    merged['relationships'].append(rel)
                    
        except json.JSONDecodeError:
            print(f"Error: Failed to decode JSON from {file_path}")
        except Exception as e:
            print(f"Error processing {file_path}: {str(e)}")

    try:
        with open(output_file, 'w') as f:
            json.dump(merged, f, indent=2)
        print(f"Successfully created merged SBOM at: {output_file}")
        print(f"Total unique packages: {len(merged['packages'])}")
    except Exception as e:
        print(f"Error writing output file: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    merge_sboms()
