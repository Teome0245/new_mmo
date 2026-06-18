import os
import re

dirs_to_delete = ['jedi', 'frs', 'gcw', 'holocron']
root_dir = '/home/sdesh/projects/new_mmo/lbg-mmo/server-core3'

cpp_extensions = ['.cpp', '.h', '.idl']

include_pattern = re.compile(r'#include\s+"server/zone/managers/(jedi|frs|gcw|holocron)/')
idl_include_pattern = re.compile(r'include\s+server\.zone\.managers\.(jedi|frs|gcw|holocron)\.')

reference_patterns = [
    re.compile(r'\b(GCWManager|JediManager|FrsManager|HolocronManager)\b'),
    re.compile(r'\b(gcwManager|jediManager|frsManager|holocronManager)\b')
]

for subdir, dirs, files in os.walk(root_dir):
    for file in files:
        if any(file.endswith(ext) for ext in cpp_extensions):
            filepath = os.path.join(subdir, file)
            with open(filepath, 'r', encoding='latin-1') as f:
                lines = f.readlines()
            
            new_lines = []
            changed = False
            for line in lines:
                if include_pattern.search(line) or idl_include_pattern.search(line):
                    changed = True
                    continue # drop include
                
                # Comment out lines with references
                if any(p.search(line) for p in reference_patterns):
                    if not line.strip().startswith('//'):
                        line = '// ' + line
                        changed = True
                
                new_lines.append(line)
            
            if changed:
                with open(filepath, 'w', encoding='latin-1') as f:
                    f.writelines(new_lines)

print("Cleanup script completed.")
