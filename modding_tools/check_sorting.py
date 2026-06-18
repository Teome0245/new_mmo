import struct
import zlib

def check_sorting(filepath):
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        names_start = record_start + record_compressed
        f.seek(names_start)
        names_data = zlib.decompress(f.read(name_compressed))
        names = names_data.decode('utf-8', errors='ignore').split('\x00')
        # Remove trailing empty string if exists
        if names and names[-1] == "":
            names.pop()
        
        is_sorted = True
        for i in range(len(names) - 1):
            if names[i] > names[i+1]:
                is_sorted = False
                print(f"Sorting violation in {os.path.basename(filepath)} at {i}: '{names[i]}' > '{names[i+1]}'")
                break
        if is_sorted:
            print(f"{os.path.basename(filepath)} is SORTED alphabetically!")

import os
check_sorting("/mnt/j/swgemu/StarWarsGalaxies/patch_14_00.tre")
check_sorting("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre")
