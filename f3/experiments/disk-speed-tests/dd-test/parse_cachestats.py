import numpy as np
import os
import sys

dname = sys.argv[1]
for i in range(15):
	iter_dname = os.path.join(dname, str(i))
	if not os.path.exists(iter_dname):
		continue

	print(iter_dname)

	with open(os.path.join(iter_dname, 'start_stop')) as f:
		start_ts, stop_ts, _ = f.readline().split(',', 2)
		start_ts = int(start_ts)
		stop_ts = int(stop_ts)

	total_hits = []
	total_misses = []
	total_dirties = []
	total_ratio = []
	total_buffers = []
	total_cache = []
	total_reads = []
	total_writes = []
	total_send = []
	total_recv = []
	for fname in [f'node-{j}-cache.stats' for j in range(9)]:
		if fname in ('node-0-cache.stats', 'node-1-cache.stats'):
			continue

		hits_res = []
		misses_res = []
		dirties_res = []
		ratio_res = []
		buffers_mb_res = []
		cache_mb_res = []
		with open(os.path.join(iter_dname, fname)) as f:
			for l in f:
				if l[0] != '1':
					continue
				ts, hits, misses, dirties, ratio, buffers_mb, cache_mb = l.split()
				ts = int(ts)
				hits = int(hits)
				misses = int(misses)
				dirties = int(dirties)
				ratio = float(ratio[:-1])
				buffers_mb = int(buffers_mb)
				cache_mb = int(cache_mb)

				#print(ts, start_ts, stop_ts)

				if ts < start_ts or ts > stop_ts:
					continue

				hits_res.append(hits)
				misses_res.append(misses)
				dirties_res.append(dirties)
				ratio_res.append(ratio)
				buffers_mb_res.append(buffers_mb)
				cache_mb_res.append(cache_mb)

				total_hits.append(hits)
				total_misses.append(misses)
				total_dirties.append(dirties)
				total_buffers.append(buffers_mb)
				total_cache.append(cache_mb)

		#print(f'{fname}')
		#for r in (hits_res, misses_res, dirties_res, ratio_res, buffers_mb_res, cache_mb_res):
		#for r in (hits_res, misses_res, buffers_mb_res, cache_mb_res):
		#	print(f'{sum(r)} {len(r)}')
			"""
			if sum(r) == 0:
				print(f'0 0 {len(r)}')
			else:
				print(f'{np.mean(r):.0f} {np.std(r)/np.mean(r):.2f} {len(r)}')
			"""

	for fname in [f'node-{j}-dstat.stats' for j in range(9)]:
		if not os.path.exists(os.path.join(iter_dname, fname)):
			continue

		if fname in ('node-0-dstat.stats', 'node-1-dstat.stats'):
			continue

		reads_res = []
		writes_res = []
		recv_res = []
		send_res = []
		with open(os.path.join(iter_dname, fname)) as f:
			for l in f:
				if l[0] != '1':
					continue
				s = l.split(',')
				ts = float(s[0])
				reads = float(s[7])*5
				writes = float(s[8])*5
				recvs = float(s[9])*5
				sends = float(s[10])*5

				if ts < start_ts or ts > stop_ts:
					continue

				reads_res.append(reads)
				writes_res.append(writes)
				recv_res.append(recvs)
				send_res.append(sends)

				total_reads.append(reads)
				total_writes.append(writes)
				total_recv.append(recvs)
				total_send.append(sends)
			print(f'{fname} {sum(reads_res)/1024/1024:>8.0f} {sum(writes_res)/1024/1024:>8.0f} {sum(recv_res)/1024/1024:>9.0f} {sum(send_res)/1024/1024:>9.0f}')

	if sum(total_hits) > 0:
		print(f'{"total":<6} {sum(total_hits):>8} {sum(total_misses):>10} {sum(total_dirties):>9} {sum(total_buffers):>9} {sum(total_cache):>9}')
		print(f'{"avg":<6} {np.mean(total_hits):>8.0f} {np.mean(total_misses):>10.0f} {np.mean(total_dirties):>9.0f} {np.mean(total_buffers):>9.0f} {np.mean(total_cache):>9.0f}')

	if sum(total_reads) > 0:
		print(f'{"total":<6} {sum(total_reads)/1024/1024:>8.0f} {sum(total_writes)/1024/1024:>10.0f} {sum(total_recv)/1024/1024:>9.0f} {sum(total_send)/1024/1024:>9.0f}')
		#print(f'{"avg":<6} {np.mean(total_reads):>8} {np.mean(total_writes):>10} {np.mean(total_recv):>9} {np.mean(total_send):>9}')
