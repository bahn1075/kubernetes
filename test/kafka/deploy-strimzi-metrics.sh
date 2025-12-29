#!/bin/bash
# Strimzi Metrics Reporter + Grafana 통합 설정 배포 스크립트

set -e

echo "========================================="
echo "Strimzi Kafka Metrics + Grafana 통합 설정"
echo "========================================="
echo ""

# 변수 설정
KAFKA_NAMESPACE="default"
MONITORING_NAMESPACE="monitoring"
KAFKA_CLUSTER="my-cluster"

# 1. Kafka 클러스터 배포/업데이트
echo "[1/5] Kafka 클러스터에 Metrics Reporter 활성화..."
kubectl apply -f /app/kubernetes/test/kafka/kafka-single-node.yaml
echo "✓ Kafka 클러스터 설정 완료"
echo ""

# 2. ServiceMonitor 배포
echo "[2/5] Prometheus ServiceMonitor 배포..."
kubectl apply -f /app/kubernetes/test/kafka/kafka-servicemonitor.yaml
echo "✓ ServiceMonitor 배포 완료"
echo ""

# 3. Prometheus 설정 업데이트
echo "[3/5] Prometheus 업데이트..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace ${MONITORING_NAMESPACE} \
  --values /app/kubernetes/monitoring/helm-values/prometheus-values.yaml \
  --wait
echo "✓ Prometheus 설정 완료"
echo ""

# 4. Grafana 대시보드 ConfigMap 생성
echo "[4/5] Grafana 대시보드 로드..."
kubectl create configmap grafana-dashboards \
  --from-file=/app/kubernetes/monitoring/grafana-dashboards/ \
  --namespace ${MONITORING_NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✓ 대시보드 ConfigMap 생성 완료"
echo ""

# 5. Grafana 업데이트
echo "[5/5] Grafana 업데이트..."
helm upgrade --install grafana grafana/grafana \
  --namespace ${MONITORING_NAMESPACE} \
  --values /app/kubernetes/monitoring/helm-values/grafana-values.yaml \
  --wait
echo "✓ Grafana 설정 완료"
echo ""

# 배포 후 상태 확인
echo "========================================="
echo "배포 상태 확인"
echo "========================================="
echo ""

echo "Kafka 클러스터 상태:"
kubectl get kafka ${KAFKA_CLUSTER} -n ${KAFKA_NAMESPACE}
echo ""

echo "Kafka 브로커 Pod 상태:"
kubectl get pods -l app.kubernetes.io/name=kafka -n ${KAFKA_NAMESPACE}
echo ""

echo "Prometheus 상태:"
kubectl get pods -n ${MONITORING_NAMESPACE} | grep prometheus
echo ""

echo "Grafana 상태:"
kubectl get pods -n ${MONITORING_NAMESPACE} | grep grafana
echo ""

# 메트릭 확인 정보
echo "========================================="
echo "메트릭 확인 방법"
echo "========================================="
echo ""
echo "1. Kafka 메트릭 엔드포인트 확인:"
echo "   kubectl port-forward -n default svc/my-cluster-kafka-brokers 9404:9404"
echo "   curl http://localhost:9404/metrics"
echo ""
echo "2. Prometheus 확인:"
echo "   kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090"
echo "   http://localhost:9090"
echo ""
echo "3. Grafana 확인:"
echo "   kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "   http://localhost:3000 (ID: admin, Password는 Secret에서 확인)"
echo ""

echo "========================================="
echo "설정 완료!"
echo "========================================="
