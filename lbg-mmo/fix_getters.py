import os

def replace_in_file(path, replacements):
    with open(path, 'r', encoding='latin-1') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(path, 'w', encoding='latin-1') as f:
        f.write(content)

replace_in_file('server-core3/server/zone/Zone.idl', [
    ('import server.zone.managers.gcw.GCWManager;', 'include server.zone.managers.ManagersStubs;'),
    ('public abstract GCWManager getGCWManager() {', 'public abstract native GCWManager getGCWManager();\n\t// {')
])

replace_in_file('server-core3/server/zone/ZoneServer.idl', [
    ('import server.zone.managers.frs.FrsManager;', 'include server.zone.managers.ManagersStubs;'),
    ('\tprivate FrsManager frsManager;', '\t// private FrsManager frsManager;'),
    ('public FrsManager getFrsManager() {\n\t\treturn frsManager;\n\t}', 'public FrsManager getFrsManager() {\n\t\treturn null;\n\t}')
])

print("Fixed IDLs")
