import numpy as np
import sys

rw = 'w'
res = {'r': [], 'w': [], 't': []}
with open(sys.argv[1]) as f:
    for l in f:
        if 'total' in l and 'YYY' not in l:
            s, _, _ = l.split()
            res[rw].append(int(s))
            if rw == 'w':
                rw = 'r'
            else:
                rw = 'w'
                res['t'].append(res['r'][-1] + res['w'][-1])

rmean = np.mean(res['r'])
wmean = np.mean(res['w'])
tmean = np.mean(res['t'])
rmed = np.median(res['r'])
wmed = np.median(res['w'])
tmed = np.median(res['t'])
#print(f'minio-obj,{wmed:.0f},{rmed:.0f},{tmed:.0f}')
print(f'minio-obj,{wmean:.0f},{rmean:.0f},{tmean:.0f}')
