#!/bin/bash

cd ../terraform

echo "[nginx]"

index=0
for i in $(aws ec2 describe-instances --filters 'Name=tag:Role,Values=test-nginx' --output json | jq -r '.Reservations[].Instances[].PublicIpAddress')
do
 let index=${index}+1
 echo "instance0${index} ansible_host=${i}"
done

echo "[nginx:vars]"

terraform output

cd ../ansible