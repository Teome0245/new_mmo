import os

def replace_in_file(path, replacements):
    with open(path, 'r', encoding='latin-1') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(path, 'w', encoding='latin-1') as f:
        f.write(content)

replace_in_file('server-core3/server/zone/Zone.idl', [
    ('public abstract native GCWManager getGCWManager();\n\t// {', 'public abstract GCWManager getGCWManager() {')
])

print("Fixed IDLs part 2")
