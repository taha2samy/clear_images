import json
import glob
import datetime
import os
import sys

def get_purl(pkg):
    """
    Extracts the Package URL (PURL) to uniquely identify a package.
    If PURL is missing, falls back to a 'name@version' composite key.
    """
    if 'externalRefs' in pkg:
        for ref in pkg['externalRefs']:
            if ref.get('referenceType') == 'purl':
                return ref.get('referenceLocator')
    
    # Fallback identifier if PURL is unavailable
    return f"{pkg.get('name')}@{pkg.get('versionInfo')}"

def merge_sboms():
    """
    Merges multiple SPDX JSON SBOM files into a single consolidated file.
    Implements smart deduplication based on Package URL (PURL) to ensure
    accurate dependency counting in GitHub Dependency Graph.
    """
    input_pattern = 'all-reports/*-sbom.spdx.json'
    output_file = 'all-reports/merged-sbom.spdx.json'
    repo_name = os.getenv('GITHUB_REPOSITORY', 'unknown/repository')

    print("--- Starting Smart SBOM Merge Process (PURL-based) ---")

    # Initialize the base structure for the merged SBOM
    merged = {
        'spdxVersion': 'SPDX-2.3',
        'dataLicense': 'CC0-1.0',
        'SPDXID': 'SPDXRef-DOCUMENT',
        'name': 'Merged-Project-SBOM',
        'documentNamespace': f'https://github.com/{repo_name}/merged-sbom',
        'creationInfo': {
            'creators': ['Tool: GitHub-Actions-Merge-Script'],
            'created': datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z')
        },
        'packages': [],
        'relationships': []
    }

    # Set to track unique packages and prevent duplicates
    seen_purls = set()
    
    # Debug: Print environment info
    print(f"Current working directory: {os.getcwd()}")
    
    files = glob.glob(input_pattern)
    print(f"DEBUG: Search pattern used: '{input_pattern}'")
    print(f"DEBUG: Found {len(files)} files: {files}")

    if not files:
        print("!!! ERROR: No SBOM files found to merge.")
        if os.path.exists('all-reports'):
             print(f"DEBUG: Contents of 'all-reports' directory: {os.listdir('all-reports')}")
        else:
             print("DEBUG: Directory 'all-reports' does not exist!")
        return

    for file_path in files:
        print(f"\nProcessing file: {file_path}")
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                
                packages = data.get('packages', [])
                relationships = data.get('relationships', [])
                
                print(f"  - Found {len(packages)} packages in this file.")
                
                # Deduplicate and merge packages
                added_count = 0
                for pkg in packages:
                    # Identify package by PURL rather than arbitrary SPDXID
                    purl = get_purl(pkg)
                    
                    if purl not in seen_purls:
                        merged['packages'].append(pkg)
                        seen_purls.add(purl)
                        added_count += 1
                    else:
                        # Duplicate package detected; skipping to avoid double counting
                        pass

                print(f"  - Added {added_count} unique packages to merged SBOM.")
                
                # Merge relationships without filtering
                for rel in relationships:
                    merged['relationships'].append(rel)
                    
        except json.JSONDecodeError:
            print(f"!!! Error: Failed to decode JSON from {file_path}")
        except Exception as e:
            print(f"!!! Error processing {file_path}: {str(e)}")

    print("\n--- Final Summary ---")
    print(f"Total unique packages in merged file: {len(merged['packages'])}")
    print(f"Total relationships collected: {len(merged['relationships'])}")

    try:
        with open(output_file, 'w') as f:
            json.dump(merged, f, indent=2)
        print(f"Successfully created merged SBOM at: {output_file}")
    except Exception as e:
        print(f"Error writing output file: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    merge_sboms()
