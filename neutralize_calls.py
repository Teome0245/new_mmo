import os
import re

root_dir = '/home/sdesh/projects/new_mmo/lbg-mmo/server-core3'
cpp_extensions = ['.cpp', '.h', '.idl']

# Look for patterns like gcwManager->, JediManager::instance()->
patterns = [
    re.compile(r'\bgcwManager->'),
    re.compile(r'\bjediManager->'),
    re.compile(r'\bfrsManager->'),
    re.compile(r'\bholocronManager->'),
    re.compile(r'\bJediManager::instance\(\)->'),
    re.compile(r'\bFrsManager::instance\(\)->')
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
                # If it's a declaration, do NOT comment the whole line out, just the RHS if possible
                # But it's complex. Let's just comment the whole line out.
                if not line.strip().startswith('//') and any(p.search(line) for p in patterns):
                    line = '// ' + line
                    changed = True
                
                new_lines.append(line)
            
            if changed:
                with open(filepath, 'w', encoding='latin-1') as f:
                    f.writelines(new_lines)

print("Neutralization completed.")
