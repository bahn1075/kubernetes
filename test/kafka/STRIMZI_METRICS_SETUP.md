# Strimzi Kafka Metrics Reporter with Grafana Setup Guide

## 개요
Strimzi Metrics Reporter를 사용하여 Kafka 클러스터의 메트릭을 Prometheus 형식으로 수집하고, Grafana를 통해 시각화합니다.

## 변경 사항

### 1. Kafka 클러스터 설정 (`kafka-single-node.yaml`)
- **metricsConfig** 추가: Strimzi Metrics Reporter 활성화
- **metrics 리스너** 추가: 9404 포트에서 메트릭 노출
- **allowList** 설정: 수집할 메트릭 지정
  - `kafka_log.*` - 로그 메트릭
  - `kafka_network.*` - 네트워크 메트릭
  - `kafka_server.*` - 서버 메트릭
  - `kafka_controller.*` - 컨트롤러 메트릭
  - `kafka_producer.*` - 프로듀서 메트릭
  - `kafka_consumer.*` - 컨슈머 메트릭

### 2. Prometheus 설정 (`prometheus-values.yaml`)
**additionalScrapeConfigs**에 Kafka 메트릭 수집 추가:
- `kafka-metrics`: 개별 Kafka 브로커 메트릭
- `kafka-broker-metrics`: Kafka 브로커 클러스터 메트릭

### 3. Grafana 대시보드 (`strimzi-kafka-metrics.json`)
Grafana 대시보드 생성:
- Kafka Cluster Status
- Network Request Rate
- Delayed Produce Requests
- Under Replicated Partitions
- Network Bytes In/Out
- Message Append Rate
- Request Latency

### 4. ServiceMonitor (`kafka-servicemonitor.yaml`)
Prometheus Operator가 자동으로 Kafka 메트릭을 발견하고 수집하도록 설정

### 5. Grafana 값 설정 (`grafana-values.yaml`)
- Prometheus 데이터 소스 추가
- Kafka 메트릭 대시보드 프로비저닝 설정

## 배포 순서

### Step 1: Kafka 클러스터 배포 및 업데이트
```bash
# 새로 배포하는 경우
kubectl apply -f /app/kubernetes/test/kafka/kafka-single-node.yaml

# 기존 클러스터 업데이트
kubectl apply -f /app/kubernetes/test/kafka/kafka-single-node.yaml

# 확인
kubectl get kafka my-cluster -o yaml | grep -A 10 metricsConfig
```

### Step 2: ServiceMonitor 배포
```bash
kubectl apply -f /app/kubernetes/test/kafka/kafka-servicemonitor.yaml

# 확인
kubectl get servicemonitor -n default
```

### Step 3: Prometheus 설정 업데이트
```bash
# Prometheus values 업데이트
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /app/kubernetes/monitoring/helm-values/prometheus-values.yaml

# 확인 (Prometheus UI에서 'kafka-metrics' 작업 확인)
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# http://localhost:9090/service-discovery
```

### Step 4: Grafana 대시보드 배포
```bash
# 대시보드 파일이 ConfigMap으로 로드되도록 설정
kubectl create configmap grafana-dashboards \
  --from-file=/app/kubernetes/monitoring/grafana-dashboards/ \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -

# Grafana 업데이트
helm upgrade grafana grafana/grafana \
  --namespace monitoring \
  -f /app/kubernetes/monitoring/helm-values/grafana-values.yaml
```

### Step 5: 메트릭 확인
```bash
# Kafka 메트릭 엔드포인트 확인
kubectl port-forward -n default svc/my-cluster-kafka-brokers 9404:9404
# http://localhost:9404/metrics

# Prometheus에서 메트릭 확인
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# http://localhost:9090/graph?query=kafka_server_broker_topics
```

## 주요 메트릭

| 메트릭 | 설명 |
|--------|------|
| `kafka_server_replica_manager_at_min_isr` | 최소 ISR 조건을 만족하는 파티션 수 |
| `kafka_network_requestmetrics_total` | 총 네트워크 요청 수 |
| `kafka_server_delayed_produce_requests` | 지연된 프로듀스 요청 |
| `kafka_server_replica_manager_under_replicated_partitions` | 복제 부족 파티션 |
| `kafka_network_requestmetrics_request_bytes` | 요청/응답 바이트 |
| `kafka_log_log_append_total` | 로그에 추가된 메시지 수 |
| `kafka_network_requestmetrics_request_latency` | 요청 지연 시간 |

## 문제 해결

### 1. Kafka 메트릭이 수집되지 않음
```bash
# Kafka 브로커 로그 확인
kubectl logs my-cluster-kafka-0

# 메트릭 리스너가 정상인지 확인
kubectl exec -it my-cluster-kafka-0 -- netstat -tlnp | grep 9404
```

### 2. Prometheus에서 메트릭을 찾을 수 없음
```bash
# ServiceMonitor 확인
kubectl describe servicemonitor kafka-metrics-monitor

# Prometheus의 Active Targets 확인
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# http://localhost:9090/targets
```

### 3. Grafana 대시보드가 데이터를 표시하지 않음
- Prometheus 데이터 소스가 정상인지 확인
- Kafka가 실행 중이고 메시지를 생성 중인지 확인
- Prometheus 보존 기간이 너무 짧지 않은지 확인

## 관련 링크
- [Strimzi Metrics Reporter](https://github.com/strimzi/metrics-reporter)
- [Strimzi 블로그](https://strimzi.io/blog/2025/10/06/strimzi-metrics-reporter/)
- [Strimzi 공식 예제](https://github.com/strimzi/strimzi-kafka-operator/tree/0.48.0/examples/metrics/strimzi-metrics-reporter)
