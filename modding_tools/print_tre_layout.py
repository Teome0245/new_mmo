import struct
import zlib

def print_tre_records(filepath):
    print(f"File layout for {filepath}:")
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        
        f.seek(record_start)
        record_block = f.read(record_compressed)
        if record_compression == 2:
            record_data = zlib.decompress(record_block)
        else:
            record_data = record_block
            
        names_start = record_start + record_compressed
        f.seek(names_start)
        name_block = f.read(name_compressed)
        if name_compression == 2:
            names_data = zlib.decompress(name_block)
        else:
            names_data = name_block
            
        names = names_data.decode('utf-8', errors='ignore').split('\x00')
        
        for i in range(min(10, len(names))):
            rec_offset = i * 24
            checksum, data_size, data_offset, data_compression, data_uncompressed, name_offset = struct.unpack('<IIIIII', record_data[rec_offset:rec_offset+24])
            name = names[i]
            print(f"Record {i}: name='{name}'")
            print(f"  data_offset={data_offset}, data_size={data_size}, uncompressed={data_uncompressed}, compression={data_compression}")

print_tre_records("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre")
