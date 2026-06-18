import os
import struct
import zlib
import sys

def sort_tre(input_path, output_path):
    print(f"Reading TRE: {input_path}")
    with open(input_path, 'rb') as f:
        header_data = f.read(36)
        if len(header_data) < 36:
            raise ValueError("Invalid header")
            
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
        
        # Read hash block
        hash_start = names_start + name_compressed
        f.seek(hash_start)
        hash_data = f.read(records * 16)
        
        # Extract records
        record_list = []
        for i in range(records):
            rec_offset = i * 24
            checksum, data_size, data_offset, data_compression, data_uncompressed, name_offset = struct.unpack('<IIIIII', record_data[rec_offset : rec_offset + 24])
            
            # Find name
            end = names_data.find(b'\x00', name_offset)
            name = names_data[name_offset:end].decode('utf-8')
            
            # Find hash
            hash_val = hash_data[i * 16 : (i + 1) * 16]
            
            record_list.append({
                'checksum': checksum,
                'data_size': data_size,
                'data_offset': data_offset,
                'data_compression': data_compression,
                'data_uncompressed': data_uncompressed,
                'name': name,
                'hash': hash_val
            })
            
    print(f"Loaded {len(record_list)} records.")
    
    # Sort by checksum
    record_list.sort(key=lambda x: x['checksum'])
    print("Sorted records by checksum.")
    
    # Rebuild names block
    new_names_data = b""
    for rec in record_list:
        rec['new_name_offset'] = len(new_names_data)
        new_names_data += rec['name'].encode('utf-8') + b'\x00'
        
    new_name_uncompressed = len(new_names_data)
    new_name_block = zlib.compress(new_names_data) if name_compression == 2 else new_names_data
    new_name_compressed = len(new_name_block)
    
    # Rebuild records block
    new_record_data = b""
    for rec in record_list:
        new_record_data += struct.pack('<IIIIII',
            rec['checksum'],
            rec['data_size'],
            rec['data_offset'],
            rec['data_compression'],
            rec['data_uncompressed'],
            rec['new_name_offset']
        )
        
    new_record_block = zlib.compress(new_record_data) if record_compression == 2 else new_record_data
    new_record_compressed = len(new_record_block)
    
    # Rebuild hash block
    new_hash_data = b"".join(rec['hash'] for rec in record_list)
    
    # Read the data block (everything between header and record_start)
    print("Copying data block...")
    with open(input_path, 'rb') as f:
        f.seek(36)
        data_block = f.read(record_start - 36)
        
    # Write output TRE
    print(f"Writing sorted TRE to: {output_path}")
    with open(output_path, 'wb') as f:
        # Write header
        header_pack = struct.pack('<8sIIIIIII',
            magic,
            records,
            record_start,
            record_compression,
            new_record_compressed,
            name_compression,
            new_name_compressed,
            new_name_uncompressed
        )
        f.write(header_pack)
        f.write(data_block)
        f.write(new_record_block)
        f.write(new_name_block)
        f.write(new_hash_data)
        
    print("Done!")

if __name__ == "__main__":
    sort_tre(sys.argv[1], sys.argv[2])
