import sys

n_w = int(sys.argv[1])
n_r = int(sys.argv[2])
p = int(sys.argv[3])

if p > n_w:
    print('!!! readers cannot read more files than there are writers')
    sys.exit()

array = list(range(0, n_w))

for r in range(0, n_r):
    lower_bound = (r*p) % n_w
    upper_bound = (r*p + p) % n_w
    
    if upper_bound == 0:
        upper_bound = n_w
    if upper_bound < lower_bound:
        lower_bound, upper_bound = upper_bound, lower_bound

    print(array[lower_bound:upper_bound])
