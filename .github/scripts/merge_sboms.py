import json
import glob
import datetime
import os
import sys

def get_purl(pkg):
    """
    Extracts the Package URL (PURL) to uniquely identify a package.
    """
    if 'externalRefs' in pkg:
        for ref in pkg['externalRefs']:
            if ref.get('referenceType') == 'purl':
                return ref.get('referenceLocator')
    return f"{pkg.get('name')}@{pkg.get('versionInfo')}"

def merge_sboms():
    input_pattern = 'all-reports/*-sbom.spdx.json'
    output_file = 'all-reports/merged-sbom.spdx.json'
    repo_name = os.getenv('GITHUB_REPOSITORY', 'unknown/repository')

    print("--- Starting Advanced SBOM Merge (With ID Remapping) ---")

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
    purl_to_id_map = {}
    
    files = glob.glob(input_pattern)
    
    if not files:
        print("!!! ERROR: No SBOM files found.")
        return

    for file_path in files:
        print(f"\nProcessing file: {file_path}")
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                
                packages = data.get('packages', [])
                relationships = data.get('relationships', [])
                
                file_id_map = {}

                # 1. Process Packages
                for pkg in packages:
                    purl = get_purl(pkg)
                    original_id = pkg.get('SPDXID')

                    if purl in purl_to_id_map:
                        kept_id = purl_to_id_map[purl]
                        file_id_map[original_id] = kept_id
                    else:
                        merged['packages'].append(pkg)
                        purl_to_id_map[purl] = original_id
                        file_id_map[original_id] = original_id 
                for rel in relationships:
                    spdx_elem_id = rel.get('spdxElementId')
                    related_elem_id = rel.get('relatedSpdxElement')

                    new_spdx_id = file_id_map.get(spdx_elem_id, spdx_elem_id)
                    new_related_id = file_id_map.get(related_elem_id, related_elem_id)

                    # Update relationship with valid IDs
                    rel['spdxElementId'] = new_spdx_id
                    rel['relatedSpdxElement'] = new_related_id
                    
                    if new_spdx_id != new_related_id:
                        merged['relationships'].append(rel)
                    
        except Exception as e:
            print(f"!!! Error processing {file_path}: {str(e)}")

    print("\n--- Final Summary ---")
    print(f"Total unique packages: {len(merged['packages'])}")
    print(f"Total relationships (remapped): {len(merged['relationships'])}")

    with open(output_file, 'w') as f:
        json.dump(merged, f, indent=2)
    print(f"Merged SBOM saved to: {output_file}")

if __name__ == "__main__":
    merge_sboms()
