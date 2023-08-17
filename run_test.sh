#!/usr/bin/bash

RESULTS=("" "" "" "" "" "")
COUNT=0
RUN_COUNT=0
TEST=("standard")
# TODO add container memory limits here.
RUNS=("docker run --name cryostat-reports --rm -d --network host quay.io/cryostat/cryostat-reports:latest")

set_up_hyperfoil(){
    echo "Setting Up Hyperfoil"

    # Start controller in standalone mode
    docker run  --name hyperfoil-container --rm -d --network host quay.io/hyperfoil/hyperfoil standalone

    # Wait for hyperfoil controller app to start up
    echo "-- Waiting for hyperfoil to start"
    while ! (curl -sf http://0.0.0.0:8090/openapi > /dev/null)
    do
        # Busy wait rather than wait some arbitrary amount of time and risk waiting too long
        :
    done
    echo "-- Done waiting for hyperfoil start-up"

    # Upload benchmark
    curl -X POST --data-binary @"$1" -H "Content-type: text/vnd.yaml" http://0.0.0.0:8090/benchmark
}

run_hyperfoil_benchmark(){
    echo "run_hyperfoil_benchmark"
    # start the benchmark
    NAME=$(curl "http://0.0.0.0:8090/benchmark/cryostat-reports-hyperfoil/start" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")

    # sleep until test is done
    sleep 10

    # Get and parse results
    readarray -d' ' results < <(curl "http://localhost:8090/run/${NAME}/stats/all/json" | python3 json_parser.py)

    echo "MEAN $((results[0]/1000000)) ms, MAX $((results[1]/1000000)) ms, 50 $((results[2]/1000000)) ms, 90 $((results[3]/1000000)) ms, 99 $((results[4]/1000000)) ms, errors ${results[5]}"
}

shutdown_hyperfoil() {
    # kill Hyperfoil standalone controller
    docker stop hyperfoil-container
    docker rm hyperfoil-container
}

wait_for_quarkus() {
    echo "-- Waiting for quarkus to start"
    # Wait for quarkus app to start up
    while ! (curl -sf http://0.0.0.0:8080/health > /dev/null)
    do
        # Busy wait rather than wait some arbitrary amount of time and risk waiting too long
        :
    done
    echo "-- Done waiting for quarkus to start"

}

shutdown_quarkus() {
    docker stop cryostat-reports
    docker rm cryostat-reports
}

run_test() {
  echo "run_test()"

  # Clear caches
  sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

  # start up jfr-data source
  ${RUNS[$((COUNT%RUN_COUNT))]}
  wait_for_quarkus

  # Run benchmark
  RESULTS[$COUNT]="$(run_hyperfoil_benchmark)"
  shutdown_quarkus
}

cleanup() {
    shutdown_quarkus
    shutdown_hyperfoil
}
trap cleanup EXIT

echo "Starting Performance Test"
CWD=$(pwd)
RUN_COUNT=${#RUNS[@]}


# Disable turbo boost and start testing
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo


set_up_hyperfoil "$CWD/benchmark.hf.yaml"

# Do test
for i in "${RUNS[@]}"
do
    run_test
    COUNT=$COUNT+1
done

shutdown_hyperfoil

# enable turbo boost again
echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

{
  echo "*****************************"
  echo "$(date)"
} >> performance_test_results.txt

for ((i=0; i<RUN_COUNT; i++));
do
    {
      echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      echo "Run ${TEST[$i]}"
      echo "Stats ${RESULTS[$i]}."
    } >> performance_test_results.txt

done
