import os
import struct
import zlib

def list_tre_files(filepath):
    print(f"Scanning TRE: {filepath}")
    if not os.path.exists(filepath):
        print("File does not exist!")
        return
        
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        if len(header_data) < 36:
            print("Invalid header length")
            return
            
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        print(f"Magic: {magic}")
        print(f"Records: {records}")
        print(f"Name compressed size: {name_compressed}, uncompressed: {name_uncompressed}")
        
        names_start = record_start + record_compressed
        f.seek(names_start)
        compressed_names = f.read(name_compressed)
        
        if name_compression == 2:  # Zlib
            try:
                names_data = zlib.decompress(compressed_names)
            except Exception as e:
                print(f"Error decompressing names block: {e}")
                return
        elif name_compression == 0:  # None
            names_data = compressed_names
        else:
            print(f"Unknown name compression: {name_compression}")
            return
            
        offset = 0
        names = []
        while offset < len(names_data):
            end = names_data.find(b'\x00', offset)
            if end == -1:
                break
            name = names_data[offset:end].decode('utf-8', errors='ignore')
            names.append(name)
            offset = end + 1
            
        print(f"Total files inside TRE: {len(names)}")
        print("First 20 files:")
        for name in names[:20]:
            print(f"  {name}")
        print("Last 20 files:")
        for name in names[-20:]:
            print(f"  {name}")

if __name__ == "__main__":
    list_tre_files("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre")
    
    # Check if specific files are in the TRE
    with open("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre", 'rb') as f:
        header_data = f.read(36)
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        names_start = record_start + record_compressed
        f.seek(names_start)
        names_data = zlib.decompress(f.read(name_compressed))
        names = names_data.decode('utf-8', errors='ignore').split('\x00')
        for target in ["string/en/ui.stf", "string/en/ui_auc.stf", "string/en/ui_skl.stf"]:
            if target in names:
                print(f"FOUND in TRE: {target}")
            else:
                print(f"NOT FOUND in TRE: {target}")

