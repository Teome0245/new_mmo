import os
import struct
import zlib

def search_tre_files(directory, target_file):
    print(f"Searching for {target_file} in {directory}...")
    for file in sorted(os.listdir(directory)):
        if file.endswith(".tre"):
            filepath = os.path.join(directory, file)
            try:
                with open(filepath, 'rb') as f:
                    header_data = f.read(36)
                    if len(header_data) < 36:
                        continue
                    magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
                    names_start = record_start + record_compressed
                    f.seek(names_start)
                    names_data = zlib.decompress(f.read(name_compressed))
                    names = names_data.decode('utf-8', errors='ignore').split('\x00')
                    if target_file in names:
                        print(f"  FOUND in {file}")
            except Exception as e:
                pass

search_tre_files("/mnt/j/swgemu/StarWarsGalaxies", "string/en/ui.stf")
