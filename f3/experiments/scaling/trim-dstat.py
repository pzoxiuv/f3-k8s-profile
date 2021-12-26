import numpy as np
import os
import sys

dname = sys.argv[1]
iter_dname = dname
#for i in range(15):
#	iter_dname = os.path.join(dname, str(i))
#	print(iter_dname)
#	if not os.path.exists(iter_dname):
#		continue

print(iter_dname)

with open(os.path.join(iter_dname, 'start_stop')) as f:
	start_ts, stop_ts, _ = f.readline().split(',', 2)
	start_ts = int(start_ts)
	stop_ts = int(stop_ts)

for fname in [f'node-{j}-dstat.stats' for j in range(10)]:
	if not os.path.exists(os.path.join(iter_dname, fname)):
		continue

	new_stats = []
	with open(os.path.join(iter_dname, fname)) as f:
		for l in f:
			if l[0] != '1':
				continue
			s = l.split(',')
			ts = float(s[0])
			if ts < start_ts or ts > stop_ts:
				continue
			new_stats.append(l)

	with open(os.path.join(iter_dname, fname), 'w') as f:
		for l in new_stats:
			f.write(l)
