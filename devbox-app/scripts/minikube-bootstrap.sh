#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ARGO_NS="argocd"
APP_NAME="devbox-app"
ARGO_INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
APP_FILE="${REPO_ROOT}/devbox-app/gitops/argocd/application.yaml"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Falta comando requerido: $1" >&2
    exit 1
  }
}

need_cmd minikube
need_cmd kubectl

if ! minikube status >/dev/null 2>&1; then
  echo "Iniciando minikube..."
  minikube start --driver=docker
else
  echo "Minikube ya esta en ejecucion."
fi

echo "Habilitando ingress..."
minikube addons enable ingress >/dev/null

if ! kubectl get ns "${ARGO_NS}" >/dev/null 2>&1; then
  kubectl create namespace "${ARGO_NS}"
fi

if ! kubectl -n "${ARGO_NS}" get deploy argocd-server >/dev/null 2>&1; then
  echo "Instalando Argo CD..."
  kubectl apply -n "${ARGO_NS}" -f "${ARGO_INSTALL_URL}"
else
  echo "Argo CD ya esta instalado."
fi

echo "Esperando despliegues de Argo CD..."
kubectl -n "${ARGO_NS}" rollout status deploy/argocd-server --timeout=300s
kubectl -n "${ARGO_NS}" rollout status deploy/argocd-repo-server --timeout=300s

[[ -f "${APP_FILE}" ]] || {
  echo "No existe Application manifest: ${APP_FILE}" >&2
  exit 1
}
kubectl apply -f "${APP_FILE}"

echo "Application aplicada: ${APP_NAME}"
echo "Si necesitas UI de Argo CD:"
echo "  kubectl -n ${ARGO_NS} port-forward svc/argocd-server 8081:443"
echo "Password inicial:"
echo "  kubectl -n ${ARGO_NS} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"

if command -v argocd >/dev/null 2>&1; then
  if argocd app get "${APP_NAME}" >/dev/null 2>&1; then
    echo "Sincronizando app con argocd CLI..."
    argocd app sync "${APP_NAME}" || true
  else
    echo "argocd CLI detectado, pero no hay sesion iniciada. Login y corre:"
    echo "  argocd app sync ${APP_NAME}"
  fi
else
  echo "argocd CLI no instalado. Sincroniza luego con kubectl/argocd UI."
fi
