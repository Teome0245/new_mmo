#!/usr/bin/env python3
import struct
import json
import os
import sys

def read_stf(path):
    with open(path, 'rb') as f:
        magic = f.read(4)
        if magic != b'\xcd\xab\x00\x00':
            raise ValueError(f"Invalid magic number in {path}")
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
        return flag, entries

def write_stf(flag, entries, path):
    with open(path, 'wb') as f:
        f.write(b'\xcd\xab\x00\x00')
        f.write(bytes([flag]))
        
        max_index = max(e["id"] for e in entries) + 1 if entries else 1
        entry_count = len(entries)
        
        f.write(struct.pack('<I', max_index))
        f.write(struct.pack('<I', entry_count))
        
        # Write values
        for entry in entries:
            f.write(struct.pack('<I', entry["id"]))
            f.write(struct.pack('<I', entry["unknown"]))
            val_bytes = entry["value"].encode('utf-16-le')
            char_count = len(entry["value"])
            f.write(struct.pack('<I', char_count))
            f.write(val_bytes)
            
        # Write keys
        for entry in entries:
            f.write(struct.pack('<I', entry["id"]))
            key_bytes = entry["key"].encode('utf-8')
            char_count = len(entry["key"])
            f.write(struct.pack('<I', char_count))
            f.write(key_bytes)

def print_usage():
    print("SWG STF Translation Tool")
    print("Usage:")
    print("  python3 stf_tool.py export <stf_file> <json_file>")
    print("  python3 stf_tool.py import <json_file> <stf_file>")
    sys.exit(1)

def main():
    if len(sys.argv) < 4:
        print_usage()
        
    action = sys.argv[1].lower()
    src = sys.argv[2]
    dst = sys.argv[3]
    
    if action == "export":
        if not os.path.exists(src):
            print(f"Error: Source file {src} does not exist.")
            sys.exit(1)
        try:
            flag, entries = read_stf(src)
            data_to_save = {
                "flag": flag,
                "entries": entries
            }
            with open(dst, 'w', encoding='utf-8') as f:
                json.dump(data_to_save, f, indent=2, ensure_ascii=False)
            print(f"Exported {len(entries)} entries from {src} to {dst}.")
        except Exception as e:
            print(f"Error exporting file: {e}")
            sys.exit(1)
            
    elif action == "import":
        if not os.path.exists(src):
            print(f"Error: Source file {src} does not exist.")
            sys.exit(1)
        try:
            with open(src, 'r', encoding='utf-8') as f:
                data = json.load(f)
            flag = data.get("flag", 1)
            entries = data.get("entries", [])
            write_stf(flag, entries, dst)
            print(f"Imported {len(entries)} entries from {src} to {dst}.")
        except Exception as e:
            print(f"Error importing file: {e}")
            sys.exit(1)
    else:
        print_usage()

if __name__ == "__main__":
    main()
