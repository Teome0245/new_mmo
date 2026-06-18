import struct
import zlib

def test_decompress_all(filepath):
    print(f"Testing decompression of all files in {filepath}...")
    with open(filepath, 'rb') as f:
        header_data = f.read(36)
        magic, records, record_start, record_compression, record_compressed, name_compression, name_compressed, name_uncompressed = struct.unpack('<8sIIIIIII', header_data)
        
        # Read records
        f.seek(record_start)
        record_block = f.read(record_compressed)
        if record_compression == 2:
            record_data = zlib.decompress(record_block)
        else:
            record_data = record_block
            
        # Read names
        names_start = record_start + record_compressed
        f.seek(names_start)
        name_block = f.read(name_compressed)
        if name_compression == 2:
            names_data = zlib.decompress(name_block)
        else:
            names_data = name_block
            
        names = names_data.decode('utf-8', errors='ignore').split('\x00')
        if names and names[-1] == "":
            names.pop()
            
        success = 0
        failed = 0
        for i in range(len(names)):
            rec_offset = i * 24
            checksum, data_uncompressed, data_offset, data_compression, data_compressed, name_offset = struct.unpack('<IIIIII', record_data[rec_offset:rec_offset+24])
            name = names[i]
            
            try:
                f.seek(data_offset)
                data = f.read(data_compressed)
                if data_compression == 2:
                    decompressed = zlib.decompress(data)
                else:
                    decompressed = data
                if len(decompressed) != data_uncompressed:
                    print(f"Size mismatch for {name}: expected {data_uncompressed}, got {len(decompressed)}")
                    failed += 1
                else:
                    success += 1
            except Exception as e:
                print(f"Failed to decompress {name}: {e}")
                failed += 1
                
        print(f"Decompression test complete: {success} succeeded, {failed} failed.")

test_decompress_all("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre")
