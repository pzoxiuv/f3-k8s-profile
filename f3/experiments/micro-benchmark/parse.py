import sys
import numpy as np

reads = {}
writes = {}
res = {}
with open(sys.argv[1]) as f:
    for l in f:
        if 'XXX' in l:
            sc, rw, _, _, _, t, _, _ = l.split(',')
            if sc not in res:
                res[sc] = []
                reads[sc] = []
                writes[sc] = []
            if rw == 'write':
                writes[sc].append(int(t)/1000)
            if rw == 'read':
                reads[sc].append(int(t)/1000)
        elif 'YYY' in l:
            t = int(l.split()[0])
            res[sc].append(t)
            sc = None

for sc, v in res.items():
    m = np.mean(v)
    #print(f'{sc:<20}{np.mean(v):.0f}\t{np.median(v):.0f}\t{np.std(v)/np.mean(v):.2f}')
    print(f'{sc:<20}{np.mean(v):.0f},{np.mean(writes[sc]):.0f},{np.mean(reads[sc]):.0f}', end='')
    print(f'{"":<10}{np.std(v)/np.mean(v):.2f},{np.std(writes[sc])/np.mean(writes[sc]):.2f},{np.std(reads[sc])/np.mean(reads[sc]):.0f}')
