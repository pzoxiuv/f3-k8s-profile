echo "Port-forwarding port 31018 to haproxypod-srvfull:5000"
kubectl -nopenwhisk port-forward pod/haproxypod-srvfull 31018:5000 &
sleep 2
port_forward_pid=$!
echo "PID for kubectl port-forward is $port_forward_pid"

echo "Testing query time..."
for i in {1..10}
do
  (printf "curl_start:"; date +%s.%6N; curl -s localhost:31018/time; printf "curl_end:"; date +%s.%6N) >> query_srvfull.dat
done

echo "Testing end to end time..."
for i in {1..10}
do
  (printf "curl_start:"; date +%s.%6N; curl -s localhost:31018/endtoend; printf "curl_end:"; date +%s.%6N) >> endtoend_srvfull.dat
done

kill $port_forward_pid

echo "Printing results..."
python calculate_results_srvfull.py