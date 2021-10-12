import numpy as np
import sys

res = {}
for fname in sys.argv[1:]:
    with open(fname) as f:
        for l in f:
            if 'XXX' not in l:
                continue

            sc, rw, _, _, _, total, b, _ = l.split(',')
            rw = rw[0]
            total = int(total)/1000
            assert int(b) == 5242880000

            if sc not in res:
                res[sc] = {'r': [], 'w': [], 't': []}

            res[sc][rw].append(total)
            if rw == 'r':
                res[sc]['t'].append(res[sc]['r'][-1] + res[sc]['w'][-1])

for sc in res:
    rmean = np.mean(res[sc]['r'])
    wmean = np.mean(res[sc]['w'])
    tmean = np.mean(res[sc]['t'])
    rmed = np.median(res[sc]['r'])
    wmed = np.median(res[sc]['w'])
    tmed = np.median(res[sc]['t'])
    rstd = np.std(res[sc]['r'])/rmean
    wstd = np.std(res[sc]['w'])/wmean
    tstd = np.std(res[sc]['t'])/tmean

    #print(f'{sc:<10}{rmean:<4.0f} {wmean:<4.0f} {tmean:<4.0f} {rmed:<4.0f} {wmed:<4.0f} {tmed:<4.0f} {rstd:.2f} {wstd:.2f} {tstd:.2f}')
    print(f'{sc},{rmed:.0f},{wmed:.0f},{tmed:.0f}')
