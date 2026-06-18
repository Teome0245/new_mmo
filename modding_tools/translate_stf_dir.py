#!/usr/bin/env python3
import struct
import json
import os
import re
import urllib.parse
import requests
import sys
import time

# Regex to match game tokens and formatting codes (like %TT, \#pcontrast1, \#.)
TOKEN_REGEX = re.compile(r'(%[A-Z]{2}|\\#[a-zA-Z0-9_]+|\\#\.)')

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
    os.makedirs(os.path.dirname(path), exist_ok=True)
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

def translate_string(text, target_lang='fr', source_lang='en'):
    if not text or not text.strip():
        return text
    
    # 1. Protect tokens by replacing them with unique placeholders
    tokens = TOKEN_REGEX.findall(text)
    protected_text = text
    placeholders = []
    
    for idx, token in enumerate(tokens):
        placeholder = f"___TK{idx}___"
        placeholders.append((placeholder, token))
        protected_text = protected_text.replace(token, placeholder, 1)
        
    # 2. Call Google Translate free API
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q={urllib.parse.quote(protected_text)}"
    
    retries = 3
    for attempt in range(retries):
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                translated = "".join([part[0] for part in data[0] if part[0]])
                break
            elif response.status_code == 429:
                # Rate limit hit, wait longer and retry
                time.sleep(2 * (attempt + 1))
            else:
                time.sleep(0.5)
        except Exception as e:
            time.sleep(0.5)
    else:
        # Fallback to original text if all retries fail
        print("Warning: Failed to translate after retries, keeping original.")
        translated = text
        
    # 3. Restore protected tokens
    for placeholder, original_token in placeholders:
        translated = re.sub(re.escape(placeholder), original_token, translated, flags=re.IGNORECASE)
        
    return translated

def translate_file(src_path, dst_path):
    print(f"Translating: {src_path} -> {dst_path}")
    try:
        flag, entries = read_stf(src_path)
        total = len(entries)
        
        for idx, entry in enumerate(entries):
            orig_val = entry["value"]
            # Print progress on the same line
            sys.stdout.write(f"\r  Progress: {idx+1}/{total} entries...")
            sys.stdout.flush()
            
            # Avoid translating file paths, image names or empty strings
            if orig_val.startswith("loading\\") or orig_val.endswith(".tga") or orig_val.endswith(".iff") or not orig_val.strip():
                continue
                
            entry["value"] = translate_string(orig_val)
            # Gentle delay to respect API rate limits
            time.sleep(0.1)
            
        sys.stdout.write("\n")
        write_stf(flag, entries, dst_path)
        print(f"  Successfully translated and saved {total} entries.")
        return True
    except Exception as e:
        print(f"\n  Error translating {src_path}: {e}")
        return False

def main():
    workspace_dir = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace"
    raw_dir = os.path.join(workspace_dir, "raw_stf")
    translated_dir = os.path.join(workspace_dir, "translated_stf")
    
    if not os.path.exists(raw_dir):
        print(f"Error: Raw STF directory '{raw_dir}' does not exist.")
        sys.exit(1)
        
    # Find all .stf files recursively
    stf_files = []
    for root, dirs, files in os.walk(raw_dir):
        for file in files:
            if file.endswith(".stf"):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, raw_dir)
                stf_files.append(rel_path)
                
    if not stf_files:
        print(f"No .stf files found in '{raw_dir}'. Extract them there first using SIE.")
        sys.exit(0)
        
    print(f"Found {len(stf_files)} STF files to translate.")
    
    success_count = 0
    for rel_path in stf_files:
        src = os.path.join(raw_dir, rel_path)
        dst = os.path.join(translated_dir, rel_path)
        
        # Check if already translated
        if os.path.exists(dst):
            print(f"Skipping (already translated): {rel_path}")
            success_count += 1
            continue
            
        if translate_file(src, dst):
            success_count += 1
            
    print(f"\nTranslation complete! {success_count}/{len(stf_files)} files translated.")

if __name__ == "__main__":
    main()
