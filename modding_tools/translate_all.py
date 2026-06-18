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

class Translator:
    def __init__(self, cache_path):
        self.cache_path = cache_path
        self.cache = {}
        self.load_cache()
        self.backoff_delay = 1.0
        
    def load_cache(self):
        if os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, 'r', encoding='utf-8') as f:
                    self.cache = json.load(f)
                print(f"Loaded {len(self.cache)} translated strings from cache.")
            except Exception as e:
                print(f"Error loading cache: {e}. Starting fresh.")
                self.cache = {}
        else:
            print("No translation cache found. Starting fresh.")
            self.cache = {}
            
    def save_cache(self):
        try:
            # Write to a temp file first then rename to ensure atomic write
            temp_path = self.cache_path + ".tmp"
            with open(temp_path, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=2, ensure_ascii=False)
            os.replace(temp_path, self.cache_path)
        except Exception as e:
            print(f"Error saving cache: {e}")

    def should_translate(self, text):
        if not text or not text.strip():
            return False
        # Avoid file paths, images, sound files
        if (text.startswith("loading\\") or 
            text.startswith("sound\\") or 
            text.endswith(".tga") or 
            text.endswith(".iff") or 
            text.endswith(".dds") or 
            text.endswith(".wav") or 
            text.endswith(".mp3")):
            return False
        # If it doesn't contain any letters, don't translate
        if not re.search(r'[a-zA-Z]', text):
            return False
        return True

    def translate_single(self, text, target_lang='fr', source_lang='en'):
        if not self.should_translate(text):
            return text
            
        if text in self.cache:
            return self.cache[text]
            
        # Protect tokens by replacing them with unique placeholders
        tokens = TOKEN_REGEX.findall(text)
        protected_text = text
        placeholders = []
        
        for idx, token in enumerate(tokens):
            placeholder = f"___TK{idx}___"
            placeholders.append((placeholder, token))
            protected_text = protected_text.replace(token, placeholder, 1)
            
        url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q={urllib.parse.quote(protected_text)}"
        
        retries = 5
        translated = text
        for attempt in range(retries):
            try:
                time.sleep(self.backoff_delay)
                response = requests.get(url, timeout=15)
                if response.status_code == 200:
                    data = response.json()
                    translated = "".join([part[0] for part in data[0] if part[0]])
                    # Reset backoff delay on successful call
                    self.backoff_delay = max(0.5, self.backoff_delay * 0.9)
                    
                    # Restore protected tokens
                    for placeholder, original_token in placeholders:
                        translated = re.sub(re.escape(placeholder), original_token, translated, flags=re.IGNORECASE)
                        
                    self.cache[text] = translated
                    return translated
                elif response.status_code == 429:
                    self.backoff_delay = min(60.0, self.backoff_delay * 2.0 + 5.0)
                    print(f"\n[429 Rate Limit] Backing off. Sleep {self.backoff_delay:.1f}s...")
                    time.sleep(self.backoff_delay)
                else:
                    time.sleep(2.0)
            except Exception as e:
                print(f"\n[Error] API call failed: {e}. Retrying...")
                time.sleep(2.0)
                
        return text

    def translate_batch(self, texts, target_lang='fr', source_lang='en'):
        # Filter texts to translate
        translate_indices = []
        texts_to_translate = []
        
        for idx, text in enumerate(texts):
            if self.should_translate(text):
                if text in self.cache:
                    texts[idx] = self.cache[text]
                else:
                    translate_indices.append(idx)
                    texts_to_translate.append(text)
                    
        if not texts_to_translate:
            return texts
            
        translated_texts = list(texts) # Copy of list
        chunk_size = 40  # safe chunk size for URL length and query size
        
        i = 0
        while i < len(texts_to_translate):
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
            
            retries = 5
            translated_payload = None
            for attempt in range(retries):
                try:
                    time.sleep(self.backoff_delay)
                    response = requests.get(url, timeout=20)
                    if response.status_code == 200:
                        data = response.json()
                        parts = []
                        for part in data[0]:
                            if part[0]:
                                parts.append(part[0])
                        translated_payload = "".join(parts)
                        self.backoff_delay = max(0.5, self.backoff_delay * 0.9)
                        break
                    elif response.status_code == 429:
                        self.backoff_delay = min(60.0, self.backoff_delay * 2.0 + 5.0)
                        print(f"\n[429 Rate Limit] Backing off. Sleep {self.backoff_delay:.1f}s...")
                        time.sleep(self.backoff_delay)
                    else:
                        print(f"\n[HTTP {response.status_code}] Unexpected status. Sleep 3s...")
                        time.sleep(3.0)
                except Exception as e:
                    print(f"\n[Error] Connection error: {e}. Sleep 3s...")
                    time.sleep(3.0)
                    
            if translated_payload is None:
                # If chunk translation fails, fall back to individual translation to avoid losing everything
                print(f"\nWarning: Chunk translation failed. Falling back to individual mode for {len(chunk)} strings.")
                for idx, text in enumerate(chunk):
                    orig_idx = chunk_indices[idx]
                    translated_texts[orig_idx] = self.translate_single(text, target_lang, source_lang)
                i += chunk_size
                continue
                
            # Restore tokens
            for placeholder, original_token in chunk_placeholders:
                translated_payload = re.sub(re.escape(placeholder), original_token, translated_payload, flags=re.IGNORECASE)
                
            translated_lines = translated_payload.split('\n')
            
            if len(translated_lines) == len(chunk):
                for idx, line in enumerate(translated_lines):
                    orig_idx = chunk_indices[idx]
                    orig_text = chunk[idx]
                    trans_text = line.strip()
                    translated_texts[orig_idx] = trans_text
                    self.cache[orig_text] = trans_text
            else:
                # Fallback to individual translations if line count mismatch
                print(f"\nWarning: Line count mismatch in chunk ({len(translated_lines)} vs {len(chunk)}). Using individual fallback.")
                for idx, text in enumerate(chunk):
                    orig_idx = chunk_indices[idx]
                    translated_texts[orig_idx] = self.translate_single(text, target_lang, source_lang)
                    
            i += chunk_size
            
        return translated_texts

def main():
    workspace_dir = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace"
    raw_dir = os.path.join(workspace_dir, "raw_stf")
    translated_dir = os.path.join(workspace_dir, "translated_stf")
    cache_path = os.path.join(workspace_dir, "translation_cache.json")
    
    if not os.path.exists(raw_dir):
        print(f"Error: Raw directory '{raw_dir}' does not exist.")
        sys.exit(1)
        
    os.makedirs(translated_dir, exist_ok=True)
    
    # 1. Initialize translator
    translator = Translator(cache_path)
    
    # 2. Get list of all STF files
    all_files = []
    for root, dirs, files in os.walk(raw_dir):
        for file in files:
            if file.endswith(".stf"):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, raw_dir)
                all_files.append(rel_path)
                
    all_files = sorted(all_files)
    total_files = len(all_files)
    print(f"Found {total_files} total STF files in client archives.")
    
    # 3. Filter files that are already completed
    files_to_process = []
    for rel_path in all_files:
        dst = os.path.join(translated_dir, rel_path)
        if not os.path.exists(dst):
            files_to_process.append(rel_path)
            
    print(f"{total_files - len(files_to_process)} files are already translated. {len(files_to_process)} remaining files to process.")
    
    if not files_to_process:
        print("All files are already translated!")
        rebuild_and_copy(workspace_dir)
        sys.exit(0)
        
    start_time = time.time()
    processed_count = 0
    saved_counter = 0
    
    # Process files
    for idx, rel_path in enumerate(files_to_process):
        src = os.path.join(raw_dir, rel_path)
        dst = os.path.join(translated_dir, rel_path)
        
        # Print progress overview
        pct = (total_files - len(files_to_process) + idx) * 100 / total_files
        print(f"[{pct:.1f}%] File {total_files - len(files_to_process) + idx + 1}/{total_files}: {rel_path}")
        
        if os.path.getsize(src) == 0:
            # Keep 0-byte file
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            open(dst, 'wb').close()
            processed_count += 1
            continue
            
        try:
            flag, entries = read_stf(src)
            original_values = [e["value"] for e in entries]
            
            # Batch translate
            translated_values = translator.translate_batch(original_values)
            
            for entry_idx, entry in enumerate(entries):
                entry["value"] = translated_values[entry_idx]
                
            write_stf(flag, entries, dst)
            processed_count += 1
            saved_counter += 1
            
            # Periodically save cache to prevent data loss (every 10 files)
            if saved_counter >= 10:
                translator.save_cache()
                saved_counter = 0
                elapsed = time.time() - start_time
                print(f"  -> Cache auto-saved. Elapsed time: {elapsed:.1f}s. Current cache size: {len(translator.cache)} items.")
                
        except Exception as e:
            print(f"Error processing {rel_path}: {e}")
            # Save cache to be safe
            translator.save_cache()
            
    # Final cache save
    translator.save_cache()
    print(f"\nFinished translating {processed_count} files in {time.time() - start_time:.1f}s.")
    
    # Rebuild and copy the TRE patch
    rebuild_and_copy(workspace_dir)

def rebuild_and_copy(workspace_dir):
    print("\nMerging into patch_fr_00.tre...")
    tre_file_path = os.path.join(workspace_dir, "patch_fr_00.tre")
    translated_dir = os.path.join(workspace_dir, "translated_stf")
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
        
        # Tri des entrées par CRC32 pour la recherche binaire du client
        print("Sorting TRE entries by CRC32 checksum...")
        sorted_tre_path = tre_file_path + ".sorted"
        sys.path.append(os.path.dirname(__file__))
        from sort_tre import sort_tre
        sort_tre(tre_file_path, sorted_tre_path)
        os.replace(sorted_tre_path, tre_file_path)
        print("TRE sorted successfully!")
        
        # Copy to the game client directory
        dest_client_path = "/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre"
        print(f"Copying {tre_file_path} to {dest_client_path}...")
        # Since we are in WSL, we can copy using standard cp
        subprocess.run(["cp", tre_file_path, dest_client_path], check=True)
        print("Patch successfully deployed to game directory!")
    except subprocess.CalledProcessError as e:
        print(f"Error merging or copying TRE file: {e}")
        print(e.stderr)

if __name__ == "__main__":
    main()
