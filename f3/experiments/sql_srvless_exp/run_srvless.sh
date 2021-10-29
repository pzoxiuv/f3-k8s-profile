echo "Port-forwarding port 31018 to haproxypod-srvless:5000"
kubectl -nopenwhisk port-forward pod/haproxypod-srvless 31018:5000 &
sleep 2
port_forward_pid=$!
echo "PID for kubectl port-forward is $port_forward_pid"

# do an initial curl just to have a warm pod for testing query time
curl -s localhost:31018/endtoend > /dev/null

echo "Testing query time..."
for i in {1..10}
do
  (printf "curl_start:"; date +%s.%6N; curl -s localhost:31018/time; printf "curl_end:"; date +%s.%6N) >> query_srvless.dat
done

echo "Testing warm end to end time..."
for i in {1..10}
do
  (printf "curl_start:"; date +%s.%6N; curl -s localhost:31018/endtoend; printf "curl_end:"; date +%s.%6N) >> endtoend_srvless_warm.dat
done

echo "Testing cold end to end time..."
for i in {1..3}
do
  echo "Restarting invoker"
  kubectl rollout restart sts owdev-invoker -nopenwhisk
  kubectl -nopenwhisk get pods | grep "^owdev-invoker" | awk '{print $1}' | xargs kubectl -nopenwhisk --timeout=30s wait --for=condition=ready pod
  printf "Waiting for invoker to be setup."
  while ! kubectl -nopenwhisk get pods | grep "whisksystem-invokerhealthtestaction"; do
    printf "."
    sleep 5
  done
  kubectl -nopenwhisk get pods | grep "whisksystem-invokerhealthtestaction" | awk '{print $1}' | xargs kubectl -nopenwhisk --timeout=30s wait --for=condition=ready pod
  sleep 5
  (printf "curl_start:"; date +%s.%6N; curl -s localhost:31018/endtoend && printf "curl_end:"; date +%s.%6N) >> endtoend_srvless_cold.dat
done

kill $port_forward_pid

echo "Printing results..."
python calculate_results_srvless.py