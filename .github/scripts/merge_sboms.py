import json
import glob
import datetime
import os
import sys

def merge_sboms():
    input_pattern = 'all-reports/*-sbom.spdx.json'
    output_file = 'all-reports/merged-sbom.spdx.json'
    repo_name = os.getenv('GITHUB_REPOSITORY', 'unknown/repository')

    print("--- Starting SBOM Merge Process ---")

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

    seen_pkg_ids = set()
    
    # طباعة المسار الحالي للتأكد
    print(f"Current working directory: {os.getcwd()}")
    
    # البحث عن الملفات
    files = glob.glob(input_pattern)
    print(f"DEBUG: Search pattern used: '{input_pattern}'")
    print(f"DEBUG: Found {len(files)} files: {files}")

    if not files:
        print("!!! ERROR: No SBOM files found to merge.")
        # هنا ممكن نطبع محتويات الفولدر عشان نعرف إيه اللي موجود
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
                
                # دمج الباكيجات
                added_count = 0
                for pkg in packages:
                    pkg_id = pkg.get('SPDXID')
                    if pkg_id and pkg_id not in seen_pkg_ids:
                        merged['packages'].append(pkg)
                        seen_pkg_ids.add(pkg_id)
                        added_count += 1

                print(f"  - Added {added_count} unique packages to merged SBOM.")
                
                # دمج العلاقات
                for rel in relationships:
                    merged['relationships'].append(rel)
                    
        except json.JSONDecodeError:
            print(f"!!! Error: Failed to decode JSON from {file_path}")
        except Exception as e:
            print(f"!!! Error processing {file_path}: {str(e)}")

    print("\n--- Final Summary ---")
    print(f"Total unique packages in merged file: {len(merged['packages'])}")

    try:
        with open(output_file, 'w') as f:
            json.dump(merged, f, indent=2)
        print(f"Successfully created merged SBOM at: {output_file}")
    except Exception as e:
        print(f"Error writing output file: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    merge_sboms()
