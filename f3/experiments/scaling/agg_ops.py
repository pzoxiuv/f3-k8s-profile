#!/usr/bin/env python3

import sys

res = {}
with open(sys.argv[1]) as f:
	for l in f:
		if not l[0].isupper():
			continue
		op, count = l.split()
		if op not in res:
			res[op] = 0
		res[op] += int(count)

for k, v in res.items():
	print(f'{k} {v}')
