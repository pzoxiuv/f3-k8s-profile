import numpy as np
import copy
import sys

template = {'net': {'storage': [], 'app': []}, 'mem': {'min': [], 'avg': []}, 'cpu': {'max': [], 'avg': []}}
#res = {'read': copy.deepcopy(template), 'write': copy.deepcopy(template)}
res = {}

def parse_storage_net(l, l2):
    l2 = l2.strip().strip(',')
    _, sc, _, stage, _, _, vals = l.split(',', 6)
    total = sum([int(x) for x in vals.split(',')])
    _, sc, _, stage, _, _, vals = l2.split(',', 6)
    total += sum([int(x) for x in vals.split(',')])

    res[sc][stage]['net']['storage'].append(total)

def parse_net(nets):
    data = 0
    for l in nets:
        # don't double count, only look at transmit not recv
        if 'transmit' in l:
            _, sc, _, stage, _, _, vals = l.split(',', 6)
            data += sum([int(x) for x in vals.split(',')])

    res[sc][stage]['net']['app'].append(data)

fname = sys.argv[1]

with open(fname) as f:
    for l in f:
        if not l.startswith('stat'):
            continue

        l = l.strip().strip(',')
        _, sc, stat, stage, _ = l.split(',', 4)

        if sc not in res:
            res[sc] = {'read': copy.deepcopy(template), 'write': copy.deepcopy(template)}

        if stat == 'net':
            if 'storage_network' in l:
                parse_storage_net(l, f.readline())
            else:
                nets = [l.strip()] + [f.readline().strip() for i in range(0, 9)]
                parse_net(nets)
        elif stat == 'cpu_max_avg':
            m, a = l.strip().split(',')[-2:]
            res[sc][stage]['cpu']['max'].append(int(m))
            res[sc][stage]['cpu']['avg'].append(int(a))
        elif stat == 'mem_max_avg':
            m, a = l.strip().split(',')[-2:]
            res[sc][stage]['mem']['min'].append(int(m)/1024)
            res[sc][stage]['mem']['avg'].append(int(a)/1024)

for sc in res.keys():
    print(f'{sc}')
    for stage in ('write', 'read'):
        print(f'\t{stage}')

        total_net = [x+y for x,y in zip(res[sc][stage]['net']['storage'], res[sc][stage]['net']['app'])]
        print(total_net)

        net_avg = np.mean(total_net)
        net_std = np.std(total_net)/net_avg

        if sum(res[sc][stage]['net']['app']) == 0:
            net_app_avg = 0
            net_app_std = 0
        else:
            net_app_avg = np.mean(res[sc][stage]['net']['app'])
            net_app_std = np.std(res[sc][stage]['net']['app'])/net_app_avg

        mem_min_avg = np.mean(res[sc][stage]['mem']['min'])
        mem_min_std = np.std(res[sc][stage]['mem']['min'])/mem_min_avg

        mem_avg_avg = np.mean(res[sc][stage]['mem']['avg'])
        mem_avg_std = np.std(res[sc][stage]['mem']['avg'])/mem_avg_avg

        cpu_avg_avg = np.mean(res[sc][stage]['cpu']['avg'])
        cpu_avg_std = np.std(res[sc][stage]['cpu']['avg'])/cpu_avg_avg

        for label, avg, std in (('net (total)', net_avg, net_std), ('net (app)', net_app_avg, net_app_std), ('mem max', mem_min_avg, mem_min_std), ('mem avg', mem_avg_avg, mem_avg_std), ('cpu avg', cpu_avg_avg, cpu_avg_std)):
            print(f'\t\t{label}: {avg:.0f} {std:.2f}')

#print(res)
