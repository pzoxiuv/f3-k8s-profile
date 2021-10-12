import sys

res = {}
with open(sys.argv[1]) as f:
    for l in f:
        if 'XXX' in l:
            sc = l.split(',')[0]
        if 'YYY' in l:
            s = l.split()[0]
            assert sc is not None
            if sc not in res:
                res[sc] = []
            res[sc].append(int(s))

for sc in res.keys():
    for v in res[sc]:
        print(f'{sc},{v}')
