#!/usr/bin/env python3

import os
import sys
import time

OHM = 100 * 1024 * 1024

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(0)

    infname = sys.argv[1]

    print(infname)

    while not os.path.exists(infname):
        time.sleep(1)

    timeout = 10
    f = open(infname, 'rb')
    total = 0
    prev = 0
    while True:
        #print('reading...')
        b = os.read(f.fileno(), (1024*1024*1024))
        #print(f'read {len(b)} bytes')
        if len(b) > 0:
            total += len(b)
            #if (total-prev) > OHM:
            #    print('.', end='')
            #    prev = total
        else:
            if os.path.exists(f'{infname}.done'):
                f.close()
                f = open(infname, 'rb')
                f.seek(total)
                if timeout > 0:
                    #print(f'timeout {timeout}')
                    timeout -= 1
                else:
                    f.close()
                    print(f'\nRead {total} bytes')
                    sys.exit(0)
            time.sleep(1)
    print(f'\nRead {total} bytes')
