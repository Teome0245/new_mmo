import os

def check():
    for filename in ['swgemu.cfg', 'swgemu_live.cfg', 'options.cfg']:
        path = os.path.join('/mnt/j/swgemu/StarWarsGalaxies', filename)
        if os.path.exists(path):
            data = open(path, 'rb').read()
            print(f"{filename} len={len(data)}: {repr(data[:300])}")
        else:
            print(f"{filename} does not exist at {path}")

if __name__ == '__main__':
    check()
