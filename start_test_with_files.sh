#!/usr/bin/env bash
#Script created to launch Jmeter tests directly from the current terminal without accessing the jmeter master pod.
#It requires that you supply the path to the jmx file
#After execution, test script jmx file may be deleted from the pod itself but not locally.

working_dir="`pwd`"

#Get namesapce variable
tenant=`awk '{print $NF}' "$working_dir/tenant_export"`

jmx="$1"
[ -n "$jmx" ] || read -p 'Enter path to the jmx file ' jmx

if [ ! -f "$jmx" ];
then
    echo "Test script file was not found in PATH"
    echo "Kindly check and input the correct file path"
    exit
fi

test_name="$(basename "$jmx")"

#Get Master pod details

master_pod=`kubectl get po -n $tenant | grep jmeter-master | awk '{print $1}'`

kubectl cp "$jmx" -n $tenant "$master_pod:/$test_name"

# Get slaves

printf "Get number of slaves\n"

slave_pods=($(kubectl get po -n "$tenant" | grep jmeter-slave | awk '{print $1}'))

# for array iteration
slavesnum=${#slave_pods[@]}

# for split command suffix and seq generator
slavedigits="${#slavesnum}"

j=0
for i in $(seq -f "%0${slavedigits}g" 0 $((slavesnum-1)))
do
  printf "Copy %s to %s on %s\n" "./jmeter-test-files" "/" "${slave_pods[j]}"
  kubectl -n "$tenant" cp "./jmeter-test-files" "${slave_pods[j]}":/

  let j=j+1
done # for i in "${slave_pods[@]}"

printf "Number of slaves is %s\n" "${slavesnum}"


## Echo Starting Jmeter load test

kubectl exec -ti -n $tenant $master_pod -- /bin/bash /load_test "$test_name"
