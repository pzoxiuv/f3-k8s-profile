#!/usr/bin/env python3

import numpy as np
import sys

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
