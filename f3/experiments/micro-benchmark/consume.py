#!/usr/bin/env python3

import os
import sys
import time

if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit(0)

    infname = sys.argv[1]
    outfname = sys.argv[2]

    print(infname, outfname)

    #if not os.path.exists(outfname):
    #    os.mkfifo(outfname)
    of = open(outfname, 'wb', 0)

    while not os.path.exists(infname):
        time.sleep(1)

    timeout = 10
    f = open(infname, 'rb')
    total = 0
    while True:
        #print('reading...')
        b = os.read(f.fileno(), (1024*1024*1024))
        #print(f'read {len(b)} bytes')
        if len(b) > 0:
            #print('writing')
            of.write(b)
            of.flush()
            total += len(b)
        else:
            if os.path.exists(f'{infname}.done'):
                if timeout > 0:
                    timeout -= 1
                else:
                    f.close()
                    of.close()
                    sys.exit(0)
            time.sleep(1)
