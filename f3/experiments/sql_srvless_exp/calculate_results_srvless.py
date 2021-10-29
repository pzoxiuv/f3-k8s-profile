import numpy as np

f = open('query_srvless.dat', 'r')
times = f.read().splitlines()
f.close()

query_times = []

for start in range(0, len(times)-1, 5):
    query_time = float(times[start+3].split(':')[1])
    query_times.append(query_time)

query_times = np.asarray(query_times)
mean = round(query_times.mean(), 3)
stdev = round(query_times.std(), 3)
pctofmean = round(100*(stdev/mean))
print("Serverfull Results:")
print("Mean query time: " + str(mean) + "s")  # python2 no f-strings
print("  StDev/percent of mean: " + str(stdev) + "s/ " + str(pctofmean)+"%")

f = open('endtoend_srvless_warm.dat', 'r')
times = f.read().splitlines()
f.close()

endtoend_times = []
user_code_start_times = []

for start in range(0, len(times)-1, 4):
    # cant fit full date in float
    start_time = float(times[start].split(':')[1][-13:])
    user_code_start_time = float(times[start+2].split(':')[1][-13:])
    end_time = float(times[start+3].split(':')[1][-13:])
    endtoend_times.append(end_time-start_time)
    user_code_start_times.append(user_code_start_time-start_time)

endtoend_times = np.asarray(endtoend_times)
mean_endtoend = round(endtoend_times.mean(), 6)
stdev_endtoend = round(endtoend_times.std(), 6)
pctofmean_endtoend = round(100*(stdev_endtoend/mean_endtoend))
print("Mean warm endtoend time: " + str(mean_endtoend) + "s")
print("  StdDev/percent of mean: " + str(stdev_endtoend) +
      "s/ " + str(pctofmean_endtoend)+"%")

user_code_start_times = np.asarray(user_code_start_times)
mean_user_code_start = round(user_code_start_times.mean(), 6)
stdev_user_code_start = round(user_code_start_times.std(), 6)
pctofmean_user_code_start = round(
    100*(stdev_user_code_start/mean_user_code_start))
print("Mean warm user code start time: " + str(mean_user_code_start) + "s")
print("  StdDev/percent of mean: " + str(stdev_user_code_start) +
      "s/ " + str(pctofmean_user_code_start) + "%")

f = open('endtoend_srvless_cold.dat', 'r')
times = f.read().splitlines()
f.close()

endtoend_times = []
user_code_start_times = []

for start in range(0, len(times)-1, 4):
    # cant fit full date in float
    start_time = float(times[start].split(':')[1][-13:])
    user_code_start_time = float(times[start+2].split(':')[1][-13:])
    end_time = float(times[start+3].split(':')[1][-13:])
    endtoend_times.append(end_time-start_time)
    user_code_start_times.append(user_code_start_time-start_time)

endtoend_times = np.asarray(endtoend_times)
mean_endtoend = round(endtoend_times.mean(), 6)
stdev_endtoend = round(endtoend_times.std(), 6)
pctofmean_endtoend = round(100*(stdev_endtoend/mean_endtoend))
print("Mean cold endtoend time: " + str(mean_endtoend) + "s")
print("  StdDev/percent of mean: " + str(stdev_endtoend) +
      "s/ " + str(pctofmean_endtoend)+"%")

user_code_start_times = np.asarray(user_code_start_times)
mean_user_code_start = round(user_code_start_times.mean(), 6)
stdev_user_code_start = round(user_code_start_times.std(), 6)
pctofmean_user_code_start = round(
    100*(stdev_user_code_start/mean_user_code_start))
print("Mean cold user code start time: " + str(mean_user_code_start) + "s")
print("  StdDev/percent of mean: " + str(stdev_user_code_start) +
      "s/ " + str(pctofmean_user_code_start) + "%")
