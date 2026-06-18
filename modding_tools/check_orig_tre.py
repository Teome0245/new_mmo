import os
import struct
import zlib

def check_orig_tre(filepath):
    print(f"Scanning original TRE: {filepath}")
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        names_start = record_start + record_compressed
        f.seek(names_start)
        names_data = zlib.decompress(f.read(name_compressed))
        names = names_data.decode('utf-8', errors='ignore').split('\x00')
        print(f"Total files: {len(names)}")
        print("Sample files:")
        for name in names[:30]:
            if "string/en/" in name.lower() or "string\\" in name.lower():
                print(f"  {name}")

check_orig_tre("/mnt/j/swgemu/StarWarsGalaxies/patch_14_00.tre")
