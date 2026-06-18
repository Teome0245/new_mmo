import os
import struct
import zlib
import sys

def extract_tre_stf(filepath, dest_dir):
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        if len(header_data) < 36:
            return
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        
        # Read records block
        f.seek(record_start)
        record_block = f.read(record_compressed)
        record_data = zlib.decompress(record_block) if record_compression == 2 else record_block
        
        # Read names block
        names_start = record_start + record_compressed
        f.seek(names_start)
        name_block = f.read(name_compressed)
        names_data = zlib.decompress(name_block) if name_compression == 2 else name_block
        
        names = names_data.decode('utf-8', errors='ignore').split('\x00')
        if names and names[-1] == "":
            names.pop()
            
        for i, name in enumerate(names):
            lower_name = name.lower()
            if not lower_name.endswith('.stf'):
                continue
                
            parts = name.split('/')
            if len(parts) >= 3 and parts[0].lower() == 'string':
                # Map original locale (en or ja) to 'en'
                parts[1] = 'en'
                dest_rel_path = "/".join(parts)
            else:
                continue
                
            rec_offset = i * 24
            checksum, data_size, data_offset, data_compression, data_uncompressed, name_offset = struct.unpack('<IIIIII', record_data[rec_offset:rec_offset+24])
            
            # Read file data
            f.seek(data_offset)
            compressed_data = f.read(data_size)
            try:
                file_data = zlib.decompress(compressed_data) if data_compression == 2 else compressed_data
            except Exception as e:
                print(f"Error decompressing {name} in {os.path.basename(filepath)}: {e}")
                continue
                
            # Write to destination
            dest_path = os.path.join(dest_dir, dest_rel_path)
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            with open(dest_path, 'wb') as out_f:
                out_f.write(file_data)

def main():
    client_dir = "/mnt/j/swgemu/StarWarsGalaxies"
    workspace_dir = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace"
    dest_dir = os.path.join(workspace_dir, "raw_stf")
    
    # TRE files in order of lowest to highest priority
    tre_files = [
        "bottom.tre",
        "data_music_00.tre",
        "data_sample_00.tre", "data_sample_01.tre", "data_sample_02.tre", "data_sample_03.tre", "data_sample_04.tre",
        "data_animation_00.tre",
        "data_skeletal_mesh_00.tre", "data_skeletal_mesh_01.tre",
        "data_texture_00.tre", "data_texture_01.tre", "data_texture_02.tre", "data_texture_03.tre", "data_texture_04.tre", "data_texture_05.tre", "data_texture_06.tre", "data_texture_07.tre",
        "data_static_mesh_00.tre", "data_static_mesh_01.tre",
        "data_other_00.tre",
        "patch_00.tre", "patch_01.tre", "patch_02.tre", "patch_03.tre", "patch_04.tre", "patch_05.tre", "patch_06.tre", "patch_07.tre", "patch_08.tre", "patch_09.tre", "patch_10.tre",
        "data_sku1_00.tre", "data_sku1_01.tre", "data_sku1_02.tre", "data_sku1_03.tre", "data_sku1_04.tre", "data_sku1_05.tre",
        "patch_11_00.tre", "patch_11_01.tre",
        "data_sku1_06.tre",
        "patch_11_02.tre",
        "data_sku1_07.tre",
        "patch_11_03.tre",
        "patch_12_00.tre",
        "patch_sku1_12_00.tre",
        "patch_13_00.tre",
        "patch_sku1_13_00.tre",
        "patch_14_00.tre",
        "patch_sku1_14_00.tre",
        "default_patch.tre"
    ]
    
    print("Extracting all active STF files from client TRE archives...")
    for tre in tre_files:
        filepath = os.path.join(client_dir, tre)
        if os.path.exists(filepath):
            print(f"  Processing {tre}...")
            extract_tre_stf(filepath, dest_dir)
            
    print("Extraction complete!")

if __name__ == "__main__":
    main()
