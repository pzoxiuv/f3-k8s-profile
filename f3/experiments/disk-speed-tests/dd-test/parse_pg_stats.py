import numpy as np
import os
import sys

dname = sys.argv[1]

sizes = [10] + [100+(x*10) for x in range(10)] + [x*100 for x in range(2, 10)] + [x*1000 for x in range(31)] + [2000+(x*100) for x in range(10)] + [2350]
#sizes = [2200]

for sc in ('f3non', 'cephfs'):
	for size in sorted(sizes):
		#for readers in (1, 5, 10, 50, 100):
		for readers in (100,):
			reads = []
			writes = []
			e2edir = f'e2e-{sc}-{size}-{readers}-readers-fulltest3'
			if not os.path.exists(os.path.join(dname, e2edir)):
				continue
			for i in range(0, 10):
				fname = os.path.join(dname, e2edir, str(i), 'pg_stats')
				if not os.path.exists(fname):
					continue
				with open(fname) as f:
					stats = f.readline()
				read, write, _ = stats.split(',', 2)
				reads.append(int(read))
				writes.append(int(write))
				fname = os.path.join(dname, e2edir, str(i), 'pod-nodes')
				node_2_pods = 0
				total_pods = 0
				pod_counts = [0]*10
				with open(fname) as f:
					for l in f:
						total_pods += 1
						if 'node-2' in l:
							node_2_pods += 1
						_, node = l.split()
						node_num = node.split('-')[-1]
						pod_counts[int(node_num)] += 1
				#print(f'{int(read)/1024:.0f} {node_2_pods} {node_2_pods/total_pods:.2f}')
				print(f'{int(read)/1024:.0f}, {int(write)/1024:.0f}')
				#print(pod_counts)
			print(f'{sc} {size} {readers} {np.mean(reads)/1024:.0f} {np.std(reads)/np.mean(reads):.2f} {np.mean(writes)/1024:.0f} {np.std(writes)/np.mean(writes):.2f}')
			#print(pod_counts)
