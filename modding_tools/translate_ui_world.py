#!/usr/bin/env python3
import struct
import json
import os
import re
import urllib.parse
import requests
import sys
import time
import subprocess

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
                time.sleep(2 * (attempt + 1))
            else:
                time.sleep(0.5)
        except Exception:
            time.sleep(0.5)
    else:
        print("Warning: Failed to translate after retries, keeping original.")
        translated = text
        
    # 3. Restore protected tokens
    for placeholder, original_token in placeholders:
        translated = re.sub(re.escape(placeholder), original_token, translated, flags=re.IGNORECASE)
        
    return translated

def translate_batch(texts, target_lang='fr', source_lang='en'):
    translate_indices = []
    texts_to_translate = []
    
    for idx, text in enumerate(texts):
        if text and text.strip():
            # Avoid translating file paths, image names
            if not (text.startswith("loading\\") or text.endswith(".tga") or text.endswith(".iff")):
                translate_indices.append(idx)
                texts_to_translate.append(text)
                
    if not texts_to_translate:
        return texts
        
    translated_texts = list(texts) # Copy of original list
    chunk_size = 25  # safe chunk size
    
    for i in range(0, len(texts_to_translate), chunk_size):
        chunk = texts_to_translate[i : i + chunk_size]
        chunk_indices = translate_indices[i : i + chunk_size]
        
        protected_chunk = []
        chunk_placeholders = []
        
        placeholder_counter = 0
        for text in chunk:
            tokens = TOKEN_REGEX.findall(text)
            protected_text = text
            for token in tokens:
                placeholder = f"___TK{placeholder_counter}___"
                chunk_placeholders.append((placeholder, token))
                protected_text = protected_text.replace(token, placeholder, 1)
                placeholder_counter += 1
            protected_chunk.append(protected_text)
            
        payload = "\n".join(protected_chunk)
        url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q={urllib.parse.quote(payload)}"
        
        retries = 3
        translated_payload = None
        for attempt in range(retries):
            try:
                response = requests.get(url, timeout=15)
                if response.status_code == 200:
                    data = response.json()
                    parts = []
                    for part in data[0]:
                        if part[0]:
                            parts.append(part[0])
                    translated_payload = "".join(parts)
                    break
                elif response.status_code == 429:
                    time.sleep(3 * (attempt + 1))
                else:
                    time.sleep(1)
            except Exception:
                time.sleep(1)
                
        if translated_payload is None:
            print(f"\nWarning: Failed to translate chunk {i//chunk_size + 1}, keeping originals.")
            continue
            
        for placeholder, original_token in chunk_placeholders:
            translated_payload = re.sub(re.escape(placeholder), original_token, translated_payload, flags=re.IGNORECASE)
            
        translated_lines = translated_payload.split('\n')
        
        if len(translated_lines) == len(chunk):
            for idx, line in enumerate(translated_lines):
                orig_idx = chunk_indices[idx]
                translated_texts[orig_idx] = line.strip()
        else:
            print(f"\nWarning: Chunk {i//chunk_size + 1} line count mismatch ({len(translated_lines)} vs {len(chunk)}). Falling back to individual translation.")
            for idx, text in enumerate(chunk):
                orig_idx = chunk_indices[idx]
                translated_texts[orig_idx] = translate_string(text, target_lang, source_lang)
                
        time.sleep(0.3)
        
    return translated_texts

def translate_file(src_path, dst_path):
    if os.path.getsize(src_path) == 0:
        print(f"Skipping empty file: {src_path}")
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        open(dst_path, 'wb').close()
        return True
        
    print(f"Translating: {src_path} -> {dst_path}")
    try:
        flag, entries = read_stf(src_path)
        total = len(entries)
        
        original_values = [entry["value"] for entry in entries]
        translated_values = translate_batch(original_values)
        
        for idx, entry in enumerate(entries):
            entry["value"] = translated_values[idx]
            
        write_stf(flag, entries, dst_path)
        print(f"  Successfully translated and saved {total} entries.")
        return True
    except Exception as e:
        print(f"\n  Error translating {src_path}: {e}")
        return False

def matches_selection(filename):
    filename = filename.lower()
    return (
        filename.startswith("ui") or 
        filename.startswith("cmd") or 
        filename.startswith("obj") or 
        filename.startswith("item") or 
        "creature_names" in filename or 
        filename.startswith("planet") or 
        filename.endswith("_planet.stf") or 
        filename.startswith("skill") or 
        filename.startswith("species") or 
        filename.startswith("faction") or 
        filename.startswith("npc_")
    )

def main():
    workspace_dir = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace"
    raw_dir = os.path.join(workspace_dir, "raw_stf")
    translated_dir = os.path.join(workspace_dir, "translated_stf")
    
    if not os.path.exists(raw_dir):
        print(f"Error: Raw STF directory '{raw_dir}' does not exist.")
        sys.exit(1)
        
    selected_files = []
    for root, dirs, files in os.walk(raw_dir):
        for file in files:
            if file.endswith(".stf") and matches_selection(file):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, raw_dir)
                selected_files.append(rel_path)
                
    if not selected_files:
        print(f"No matching .stf files found in '{raw_dir}'.")
        sys.exit(0)
        
    print(f"Found {len(selected_files)} UI/World STF files to process.")
    
    success_count = 0
    for idx, rel_path in enumerate(sorted(selected_files)):
        src = os.path.join(raw_dir, rel_path)
        dst = os.path.join(translated_dir, rel_path)
        
        if os.path.exists(dst):
            print(f"[{idx+1}/{len(selected_files)}] Skipping (already exists): {rel_path}")
            success_count += 1
            continue
            
        print(f"[{idx+1}/{len(selected_files)}] Processing:")
        if translate_file(src, dst):
            success_count += 1
            
    print(f"\nTranslation complete! {success_count}/{len(selected_files)} files translated/ready.")

    print("\nMerging into patch_fr_00.tre...")
    tre_file_path = os.path.join(workspace_dir, "patch_fr_00.tre")
    cmd = [
        "/home/sdesh/.cargo/bin/swg", "tre", "merge",
        "--directory", translated_dir,
        "--file", tre_file_path,
        "--overwrite"
    ]
    try:
        res = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print("TRE Merge output:")
        print(res.stdout)
        print("TRE package updated successfully!")
    except subprocess.CalledProcessError as e:
        print(f"Error merging TRE file: {e}")
        print(e.stderr)

if __name__ == "__main__":
    main()
