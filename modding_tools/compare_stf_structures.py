import struct

def read_stf(path):
    with open(path, 'rb') as f:
        magic = f.read(4)
        if magic != b'\xcd\xab\x00\x00':
            raise ValueError(f"Invalid magic number")
        flag = f.read(1)[0]
        max_index = struct.unpack('<I', f.read(4))[0]
        entry_count = struct.unpack('<I', f.read(4))[0]
        
        values = {}
        for _ in range(entry_count):
            entry_id = struct.unpack('<I', f.read(4))[0]
            unknown = struct.unpack('<I', f.read(4))[0]
            char_count = struct.unpack('<I', f.read(4))[0]
            data = f.read(char_count * 2).decode('utf-16-le')
            values[entry_id] = (unknown, data)
            
        keys = {}
        for _ in range(entry_count):
            entry_id = struct.unpack('<I', f.read(4))[0]
            char_count = struct.unpack('<I', f.read(4))[0]
            data = f.read(char_count).decode('utf-8')
            keys[entry_id] = data
            
        entries = []
        for entry_id in keys:
            unknown, val = values[entry_id]
            key = keys[entry_id]
            entries.append({
                "id": entry_id,
                "key": key,
                "value": val,
                "unknown": unknown
            })
        return flag, max_index, entry_count, entries

# Extract the original ui.stf from patch_14_00.tre first
import subprocess
try:
    subprocess.run([
        "/home/sdesh/.cargo/bin/swg", "tre", "extract",
        "--file", "/mnt/j/swgemu/StarWarsGalaxies/patch_14_00.tre",
        "--directory", "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/orig_extracted"
    ], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
except Exception as e:
    print("Error extracting original:", e)

orig_path = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/orig_extracted/string/en/ui.stf"
trans_path = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/extracted_test/string/en/ui.stf"

orig_flag, orig_max, orig_cnt, orig_entries = read_stf(orig_path)
trans_flag, trans_max, trans_cnt, trans_entries = read_stf(trans_path)

print(f"Original: flag={orig_flag}, max_index={orig_max}, count={orig_cnt}")
print(f"Translated: flag={trans_flag}, max_index={trans_max}, count={trans_cnt}")

# Compare keys
orig_keys = set(e["key"] for e in orig_entries)
trans_keys = set(e["key"] for e in trans_entries)

missing_keys = orig_keys - trans_keys
extra_keys = trans_keys - orig_keys

print(f"Missing keys in translated: {len(missing_keys)}")
print(f"Extra keys in translated: {len(extra_keys)}")

if len(orig_entries) == len(trans_entries):
    print("Entries count matches!")
    mismatches = 0
    for i in range(len(orig_entries)):
        o = orig_entries[i]
        t = trans_entries[i]
        if o["id"] != t["id"]:
            print(f"ID mismatch at {i}: orig={o['id']}, trans={t['id']}")
            mismatches += 1
        if o["key"] != t["key"]:
            print(f"Key mismatch at {i}: orig={o['key']}, trans={t['key']}")
            mismatches += 1
        if o["unknown"] != t["unknown"]:
            print(f"Unknown mismatch at {i}: orig={o['unknown']}, trans={t['unknown']}")
            mismatches += 1
    print(f"Structure mismatches: {mismatches}")
else:
    print("Entries count does not match!")
