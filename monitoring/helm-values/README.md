# Monitoring Stack Installation Guide

## 개요

이 디렉토리는 Kubernetes 클러스터에 Full Stack Monitoring을 설치하기 위한 Helm values 파일들을 포함합니다.

### 구성 요소
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 시각화 및 대시보드
- **Loki**: 로그 수집 및 저장
- **Alloy**: 로그 및 메트릭 수집 에이전트
- **Tempo**: 분산 트레이싱

## 사전 요구사항

### 1. PV/PVC 생성 (필수)

**Helm 설치를 실행하기 전에 반드시 PV와 PVC를 먼저 생성해야 합니다.**

PV/PVC 파일 위치: `/app/kubernetes/monitoring/pv-pvc/`

#### 필수 PVC 목록
- `grafana-pvc` (5Gi, RWX)
- `loki-pvc` (5Gi, RWX)
- `prometheus-pvc` (5Gi, RWX)

#### PV/PVC 생성 방법

```bash
# 1. monitoring namespace 생성
kubectl create namespace monitoring

# 2. PV 생성
cd /app/kubernetes/monitoring/pv-pvc
kubectl apply -f grafana-pv.yaml
kubectl apply -f loki-pv.yaml
kubectl apply -f prometheus-pv.yaml

# 3. PVC 생성
kubectl apply -f grafana-pvc.yaml
kubectl apply -f loki-pvc.yaml
kubectl apply -f promtheus-pvc.yaml  # 주의: 파일명 오타 있음 (promtheus)

# 4. PVC 상태 확인
kubectl get pvc -n monitoring
```

#### 확인 사항
모든 PVC가 `Bound` 상태여야 합니다:
```
NAME             STATUS   VOLUME          CAPACITY   ACCESS MODES
grafana-pvc      Bound    grafana-pv      5Gi        RWX
loki-pvc         Bound    loki-pv         5Gi        RWX
prometheus-pvc   Bound    prometheus-pv   5Gi        RWX
```

### 2. Grafana Admin Secret 생성

```bash
kubectl create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=admin123 \
  -n monitoring
```

### 3. Ingress Controller

Grafana에 외부 접근을 위해 Ingress Controller가 필요합니다:
- NGINX Ingress Controller 권장
- 설정된 도메인: `grafana.64bit.kr`

## 설치 방법

### 자동 설치 (권장)

```bash
cd /app/kubernetes/monitoring/helm-values
chmod +x install.sh
./install.sh
```

### 수동 설치

```bash
# Helm repository 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 1. Prometheus 설치
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --wait --timeout=600s

# 2. Loki 설치
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values loki-values.yaml \
  --wait --timeout=600s

# 3. Alloy 설치
helm upgrade --install alloy grafana/alloy \
  --namespace monitoring \
  --values alloy-values.yaml \
  --wait --timeout=600s

# 4. Tempo 설치
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  --values tempo-values.yaml \
  --wait --timeout=600s

# 5. Grafana 설치
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values grafana-values.yaml \
  --wait --timeout=600s

# 6. Trace Generator (테스트용)
kubectl apply -f trace-generator.yaml
```

## Storage 설정

### Prometheus
- **PVC**: `prometheus-pvc` (5Gi)
- **설정 방식**: `volumeClaimTemplate`에서 `volumeName`으로 PV 지정
- **보관 기간**: 5일

### Loki
- **PVC**: `loki-pvc` (5Gi)
- **설정 방식**: `existingClaim`으로 기존 PVC 사용
- **보관 기간**: 5일 (120시간)

### Grafana
- **PVC**: `grafana-pvc` (5Gi)
- **설정 방식**: `existingClaim`으로 기존 PVC 사용
- **데이터**: 대시보드, 플러그인, 설정

### Tempo
- **Storage**: emptyDir (영구 저장소 비활성화)
- **보관 기간**: 5일 (120시간)
- **주의**: Pod 재시작 시 데이터 손실됨

## 데이터소스 설정

Grafana는 다음 데이터소스가 자동으로 구성됩니다:

- **Prometheus**: `http://prometheus-operated.monitoring.svc.cluster.local:9090`
- **Loki**: `http://loki.monitoring.svc.cluster.local:3100`
- **Tempo**: `http://tempo.monitoring.svc.cluster.local:3200`

## 접속 정보

### Grafana
- **URL**: http://grafana.64bit.kr
- **Username**: admin
- **Password**: admin123

### Port Forward (Ingress 없이 접속)

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# AlertManager
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
```

## 문제 해결

### PVC가 Pending 상태인 경우

```bash
# PVC 상태 확인
kubectl describe pvc <pvc-name> -n monitoring

# PV 상태 확인
kubectl get pv
```

**일반적인 원인:**
- PV가 생성되지 않음
- PV의 `volumeName`과 PVC의 `volumeName`이 일치하지 않음
- Storage Class가 올바르지 않음
- Access Mode가 일치하지 않음

### Prometheus Pod가 시작되지 않는 경우

```bash
# Pod 로그 확인
kubectl logs -n monitoring prometheus-prometheus-0

# Pod 상태 확인
kubectl describe pod -n monitoring prometheus-prometheus-0
```

**일반적인 원인:**
- PVC가 Bound 상태가 아님
- 권한 문제 (fsGroup: 2000)
- 리소스 부족

### Loki Pod가 시작되지 않는 경우

```bash
# Pod 로그 확인
kubectl logs -n monitoring loki-0

# PVC 확인
kubectl get pvc loki-pvc -n monitoring
```

## 삭제

```bash
cd /app/kubernetes/monitoring/helm-values
chmod +x uninstall.sh
./uninstall.sh
```

또는 수동으로:

```bash
# Helm releases 삭제
helm uninstall grafana -n monitoring
helm uninstall tempo -n monitoring
helm uninstall alloy -n monitoring
helm uninstall loki -n monitoring
helm uninstall prometheus -n monitoring

# Trace generator 삭제
kubectl delete -f trace-generator.yaml

# PVC 삭제 (선택사항 - 데이터가 삭제됨)
kubectl delete pvc grafana-pvc loki-pvc prometheus-pvc -n monitoring

# Namespace 삭제 (선택사항)
kubectl delete namespace monitoring
```

## 참고 문서

- [FSS 통합 구성 가이드](../FSS-UNIFIED-SETUP.md)
- [PV/PVC 구성](../pv-pvc/)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/grafana)
- [Loki Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/loki)
