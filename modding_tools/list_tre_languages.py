#!/usr/bin/env python3
import os
import struct
import zlib

def scan_tre_file(filepath):
    languages = set()
    sample_paths = []
    
    with open(filepath, 'rb') as f:
        # Read header (36 bytes)
        header_data = f.read(36)
        if len(header_data) < 36:
            return None
        
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        
        # Check magic
        if magic != b'TREE0005' and magic != b'EERT5000':
            # EERT5000 is TREE0005 backwards if read as little-endian by mistake, but we read as 8s.
            # TREE0005 in bytes is b'TREE0005' or b'EERT5000' (depending on ordering).
            # Let's support both.
            if b'TREE' not in magic and b'EERT' not in magic:
                return None
        
        # Seek to names block start
        # The names block is located immediately after the record block
        names_start = record_start + record_compressed
        f.seek(names_start)
        compressed_names = f.read(name_compressed)
        
        if name_compression == 2:  # Zlib
            try:
                names_data = zlib.decompress(compressed_names)
            except Exception as e:
                print(f"Error decompressing names block in {os.path.basename(filepath)}: {e}")
                return None
        elif name_compression == 0:  # None
            names_data = compressed_names
        else:
            print(f"Unknown compression method {name_compression} in {os.path.basename(filepath)}")
            return None
            
        # Decode names_data
        # It's a sequence of null-terminated strings
        offset = 0
        names = []
        while offset < len(names_data):
            end = names_data.find(b'\x00', offset)
            if end == -1:
                break
            name = names_data[offset:end].decode('utf-8', errors='ignore')
            names.append(name)
            offset = end + 1
            
        for name in names:
            lower = name.lower()
            if lower.endswith('.stf') and 'string/' in lower:
                # Extract language
                parts = name.split('/')
                for idx, part in enumerate(parts):
                    if part.lower() == 'string' and idx + 1 < len(parts):
                        languages.add(parts[idx + 1].lower())
                if not lower.startswith('string/en/'):
                    sample_paths.append(name)
                    
    return languages, sample_paths

def main():
    client_dir = "/mnt/j/swgemu/StarWarsGalaxies"
    tre_files = [
        "bottom.tre", "data_music_00.tre", "data_sample_00.tre", "data_sample_01.tre",
        "data_sample_02.tre", "data_sample_03.tre", "data_sample_04.tre", "data_animation_00.tre",
        "data_skeletal_mesh_00.tre", "data_skeletal_mesh_01.tre", "data_texture_00.tre",
        "data_texture_01.tre", "data_texture_02.tre", "data_texture_03.tre", "data_texture_04.tre",
        "data_texture_05.tre", "data_texture_06.tre", "data_texture_07.tre", "data_static_mesh_00.tre",
        "data_static_mesh_01.tre", "data_other_00.tre", "patch_00.tre", "patch_01.tre",
        "patch_02.tre", "patch_03.tre", "patch_04.tre", "patch_05.tre", "patch_06.tre",
        "patch_07.tre", "patch_08.tre", "patch_09.tre", "patch_10.tre", "data_sku1_00.tre",
        "data_sku1_01.tre", "data_sku1_02.tre", "data_sku1_03.tre", "data_sku1_04.tre",
        "data_sku1_05.tre", "patch_11_00.tre", "patch_11_01.tre", "data_sku1_06.tre",
        "patch_11_02.tre", "data_sku1_07.tre", "patch_11_03.tre", "patch_12_00.tre",
        "patch_sku1_12_00.tre", "patch_13_00.tre", "patch_sku1_13_00.tre", "patch_14_00.tre",
        "patch_sku1_14_00.tre", "default_patch.tre", "patch_fr_00.tre"
    ]
    
    all_languages = set()
    non_en_samples = []
    
    print("Scanning TRE files inside StarWarsGalaxies client...")
    for tre in tre_files:
        path = os.path.join(client_dir, tre)
        if not os.path.exists(path):
            continue
            
        res = scan_tre_file(path)
        if res:
            langs, samples = res
            if langs:
                print(f"  {tre}: found language directories: {list(langs)}")
                all_languages.update(langs)
            if samples:
                non_en_samples.extend([(tre, s) for s in samples])
                
    print("\n==================================================")
    print(f"Total Unique Language Codes Found in string/: {list(all_languages)}")
    print("==================================================")
    
    if non_en_samples:
        print("\nFound non-English STF paths:")
        for tre, sample in non_en_samples[:20]:
            print(f"  [{tre}] -> {sample}")
    else:
        print("\nNo non-English STF paths found inside the client TREs!")

if __name__ == "__main__":
    main()
