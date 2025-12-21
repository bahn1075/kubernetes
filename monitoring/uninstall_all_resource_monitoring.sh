#!/bin/bash
set -x

echo "=== 완전 정리 시작 ==="

# 1. Helm 릴리즈 모두 삭제
helm uninstall prometheus -n monitoring 2>/dev/null || true
helm uninstall grafana -n monitoring 2>/dev/null || true
helm uninstall loki -n monitoring 2>/dev/null || true
helm uninstall tempo -n monitoring 2>/dev/null || true
helm uninstall alloy -n monitoring 2>/dev/null || true

# 2. 모든 리소스 삭제
kubectl delete all --all -n monitoring --force --grace-period=0 2>/dev/null || true

# 3. PVC 모두 삭제
kubectl delete pvc --all -n monitoring --force --grace-period=0 2>/dev/null || true

# 4. Secret 삭제 (grafana-admin 제외하고 재생성 예정)
kubectl delete secret --all -n monitoring 2>/dev/null || true

# 5. ConfigMap 삭제
kubectl delete configmap --all -n monitoring 2>/dev/null || true

# 6. Prometheus CRD 리소스 삭제
kubectl delete prometheus --all -n monitoring 2>/dev/null || true
kubectl delete alertmanager --all -n monitoring 2>/dev/null || true
kubectl delete servicemonitor --all -n monitoring 2>/dev/null || true
kubectl delete podmonitor --all -n monitoring 2>/dev/null || true
kubectl delete prometheusrule --all -n monitoring 2>/dev/null || true

# 7. StatefulSet 삭제
kubectl delete statefulset --all -n monitoring --force --grace-period=0 2>/dev/null || true

# 8. 잠시 대기
sleep 10

echo "=== 정리 완료 ==="
kubectl get all,pvc -n monitoring
