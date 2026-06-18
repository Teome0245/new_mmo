import struct

def read_stf(path):
    try:
        with open(path, 'rb') as f:
            magic = f.read(4)
            if magic != b'\xcd\xab\x00\x00':
                return None
            flag = f.read(1)[0]
            max_index = struct.unpack('<I', f.read(4))[0]
            entry_count = struct.unpack('<I', f.read(4))[0]
            
            values = {}
            for _ in range(entry_count):
                entry_id = struct.unpack('<I', f.read(4))[0]
                unknown = struct.unpack('<I', f.read(4))[0]
                char_count = struct.unpack('<I', f.read(4))[0]
                data = f.read(char_count * 2).decode('utf-16-le', errors='ignore')
                values[entry_id] = data
                
            keys = {}
            for _ in range(entry_count):
                entry_id = struct.unpack('<I', f.read(4))[0]
                char_count = struct.unpack('<I', f.read(4))[0]
                data = f.read(char_count).decode('utf-8', errors='ignore')
                keys[entry_id] = data
                
            return {keys[eid]: values[eid] for eid in keys}
    except Exception as e:
        print("Error reading STF:", e)
        return None

def main():
    ui_path = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/translated_stf/string/en/ui.stf"
    ui_content = read_stf(ui_path)
    if ui_content:
        print("ui.stf -> skill_qualify:", repr(ui_content.get("skill_qualify")))
    
    ui_skl_path = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/translated_stf/string/en/ui_skl.stf"
    ui_skl_content = read_stf(ui_skl_path)
    if ui_skl_content:
        print("ui_skl.stf -> qualify:", repr(ui_skl_content.get("qualify")))
        
    survey_path = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/translated_stf/string/en/survey.stf"
    survey_content = read_stf(survey_path)
    if survey_content:
        print("survey.stf -> sample_located:", repr(survey_content.get("sample_located")))
        print("survey.stf -> start_sampling:", repr(survey_content.get("start_sampling")))

if __name__ == "__main__":
    main()
