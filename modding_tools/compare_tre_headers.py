import struct

def print_tre_header(filepath):
    print(f"Header for {filepath}:")
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        print(f"  Magic: {magic}")
        print(f"  Records: {records}")
        print(f"  Record Start: {record_start}")
        print(f"  Record Compression: {record_compression}")
        print(f"  Record Compressed Size: {record_compressed}")
        print(f"  Name Compression: {name_compression}")
        print(f"  Name Compressed Size: {name_compressed}")
        print(f"  Name Uncompressed Size: {name_uncompressed}")

print_tre_header("/mnt/j/swgemu/StarWarsGalaxies/default_patch.tre")
print_tre_header("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre")
