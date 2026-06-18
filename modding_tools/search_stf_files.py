import os
import struct
import re

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
        return None

def main():
    raw_dir = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/raw_stf"
    search_terms = ["surveying experience", "successfully locate", "you now qualify for the skill", "god mode", "you begin to sample"]
    
    results = {term: [] for term in search_terms}
    
    for root, dirs, files in os.walk(raw_dir):
        for file in files:
            if file.endswith(".stf"):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, raw_dir)
                content = read_stf(full_path)
                if content:
                    for key, val in content.items():
                        for term in search_terms:
                            # Search in both key and value
                            if term in key.lower() or term in val.lower():
                                results[term].append((rel_path, key, val))
                                
    for term, matches in results.items():
        print(f"\n=========================================")
        print(f"Matches for '{term}': {len(matches)}")
        print(f"=========================================")
        # Print top 15 matches to avoid spamming
        for match in matches[:15]:
            print(f"File:  {match[0]}")
            print(f"  Key: {match[1]}")
            print(f"  Val: {repr(match[2])}")
            print()

if __name__ == "__main__":
    main()
