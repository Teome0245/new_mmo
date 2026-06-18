import struct
import zlib

def print_exact_name(filepath, target):
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        names_start = record_start + record_compressed
        f.seek(names_start)
        names_data = zlib.decompress(f.read(name_compressed))
        names = names_data.decode('utf-8', errors='ignore').split('\x00')
        for name in names:
            if name.lower() == target.lower():
                print(f"Exact name in {os.path.basename(filepath)}: '{name}'")

import os
print_exact_name("/mnt/j/swgemu/StarWarsGalaxies/patch_14_00.tre", "string/en/ui.stf")
print_exact_name("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre", "string/en/ui.stf")
