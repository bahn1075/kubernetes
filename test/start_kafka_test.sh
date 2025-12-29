#!/bin/bash

echo "==> Updating ConfigMap..."
kubectl delete configmap k6-script -n kafka 2>/dev/null
kubectl create configmap k6-script -n kafka --from-file=kafka-test.js

echo "==> Deleting old Job..."
kubectl delete job k6-kafka-test -n kafka 2>/dev/null

echo "==> Waiting for Job to be deleted..."
while kubectl get job k6-kafka-test -n kafka &>/dev/null; do
  echo -n "."
  sleep 1
done
echo " Done!"

echo "==> Creating new Job..."
kubectl apply -f - <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-kafka-test
  namespace: kafka
spec:
  template:
    spec:
      containers:
      - name: k6
        image: mostafamoradian/xk6-kafka:latest
        args: ["run", "/scripts/kafka-test.js"]
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      restartPolicy: Never
      volumes:
      - name: scripts
        configMap:
          name: k6-script
  backoffLimit: 1
YAML

echo "==> Waiting for Pod to start..."
sleep 2
POD_NAME=$(kubectl get pod -n kafka -l job-name=k6-kafka-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
  echo "Waiting for pod..."
  sleep 3
  POD_NAME=$(kubectl get pod -n kafka -l job-name=k6-kafka-test -o jsonpath='{.items[0].metadata.name}')
fi

echo "==> Following logs for pod: $POD_NAME"
echo "==> Waiting for Pod to be ready..."
kubectl wait --for=condition=Ready pod/$POD_NAME -n kafka --timeout=300s 2>/dev/null || true

echo "==> Waiting 15 seconds before displaying logs..."
sleep 15
kubectl logs -n kafka -f $POD_NAME
