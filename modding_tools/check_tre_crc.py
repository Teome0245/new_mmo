import struct
import zlib
import binascii

# BZIP2 CRC-32 is equivalent to CRC-32/BZIP2 (poly=0x04C11DB7, init=0xFFFFFFFF, xorout=0xFFFFFFFF, refin=false, refout=false)
# Let's write a python function to compute it
def crc32_bzip2(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for b in data:
        crc ^= (b << 24)
        for _ in range(8):
            if crc & 0x80000000:
                crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF
            else:
                crc = (crc << 1) & 0xFFFFFFFF
    return crc ^ 0xFFFFFFFF

def check_crc(filepath):
    print(f"Reading records from {filepath}...")
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
            
        for i in range(min(5, len(names))):
            rec_offset = i * 24
            checksum, data_size, data_offset, data_compression, data_uncompressed, name_offset = struct.unpack('<IIIIII', record_data[rec_offset:rec_offset+24])
            name = names[i]
            print(f"\nRecord {i}:")
            print(f"  Name: '{name}'")
            print(f"  Checksum in TRE: {checksum:08X} ({checksum})")
            
            # Compute CRCs
            name_bytes = name.encode('utf-8')
            crc_bz2_orig = crc32_bzip2(name_bytes)
            crc_bz2_lower = crc32_bzip2(name.lower().encode('utf-8'))
            crc_bz2_upper = crc32_bzip2(name.upper().encode('utf-8'))
            
            crc_std_orig = binascii.crc32(name_bytes) & 0xFFFFFFFF
            crc_std_lower = binascii.crc32(name.lower().encode('utf-8')) & 0xFFFFFFFF
            crc_std_upper = binascii.crc32(name.upper().encode('utf-8')) & 0xFFFFFFFF
            
            print(f"  CRC-32/BZIP2 (original):  {crc_bz2_orig:08X}")
            print(f"  CRC-32/BZIP2 (lowercase): {crc_bz2_lower:08X}")
            print(f"  CRC-32/BZIP2 (uppercase): {crc_bz2_upper:08X}")
            print(f"  Standard CRC-32 (orig):   {crc_std_orig:08X}")
            print(f"  Standard CRC-32 (lower):  {crc_std_lower:08X}")
            print(f"  Standard CRC-32 (upper):  {crc_std_upper:08X}")
            
            if checksum == crc_bz2_orig:
                print("  --> Matches BZIP2 (original)")
            if checksum == crc_bz2_lower:
                print("  --> Matches BZIP2 (lowercase)")
            if checksum == crc_bz2_upper:
                print("  --> Matches BZIP2 (uppercase)")
            if checksum == crc_std_orig:
                print("  --> Matches Standard (original)")
            if checksum == crc_std_lower:
                print("  --> Matches Standard (lowercase)")
            if checksum == crc_std_upper:
                print("  --> Matches Standard (uppercase)")

check_crc("/mnt/j/swgemu/StarWarsGalaxies/patch_fr_00.tre")
