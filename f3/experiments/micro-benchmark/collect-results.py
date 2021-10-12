import sys
import numpy as np

res = {}
with open(sys.argv[1]) as f:
    for l in f:
        if 'XXX' not in l:
            continue
        sc, op, o, rw, c, total, b, _ = l.split(',')
        if sc not in res:
            res[sc] = {'read': {'open': [], 'read': [], 'close': [], 'total': []}, 'write': {'open': [], 'write': [], 'close': [], 'total': []}}

        res[sc][op]['open'].append(int(o))
        res[sc][op][op].append(int(rw))
        res[sc][op]['close'].append(int(c))
        res[sc][op]['total'].append(int(total))

#print(res)

for sc in res:
    print(f'{sc}')
    for rw in ('write', 'read'):
        print(f'\t{rw}')
        for stat in ('open', rw, 'close', 'total'):
            s = res[sc][rw][stat]
            mean = np.mean(s)
            med = np.median(s)
            if mean == 0:
                std = 0
            else:
                std = np.std(s)/mean
            if mean > 10000:
                mean /= 1000
            if med > 10000:
                med /= 1000
            print(f'\t\t{stat}:\t{mean:.0f}\t{med:.0f}\t{std:.2f}')
