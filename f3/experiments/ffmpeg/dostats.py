#!/usr/bin/env python3

import matplotlib.pyplot as plt
import numpy as np
import sys

def means(res, sc):
    return [np.mean(x) for x in res[sc].values()]

def errs(res, sc):
    return [np.std(x) for x in res[sc].values()]

res = {}
with open(sys.argv[1]) as f:
	for l in f:
		sc, numworkers, totaltime = l.split()
		numworkers = int(numworkers)
		totaltime = float(totaltime)

		if sc not in res:
			res[sc] = {}
		if numworkers not in res[sc]:
			res[sc][numworkers] = []
		res[sc][numworkers].append(totaltime)

for sc in res.keys():
	print(f'{sc}')
	for numworkers in sorted(res[sc].keys()):
		d = res[sc][numworkers]
		print(f'  {numworkers} {np.mean(d):.0f} {np.std(d)/np.mean(d):.2f}')

width=.3
x = np.arange(len(res['f3']))
plt.bar(x, means(res, 'f3'), width, label='f3', yerr=errs(res, 'f3'))
plt.bar(x+width, means(res, 'f3non'), width, label='f3 non ID', yerr=errs(res, 'f3non'))
plt.bar(x-width, means(res, 'ceph'), width, label='ceph', yerr=errs(res, 'ceph'))

plt.ylabel('Total time (s)')
plt.xlabel('Number of workers')
plt.xticks(x, [str(x) for x in res['f3'].keys()])

plt.legend()
#plt.show()
#plt.savefig('ffmpeg-results.png', dpi=600, bbox_layout='tight')
