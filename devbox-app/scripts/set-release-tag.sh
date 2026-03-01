#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "${TAG}" ]]; then
  echo "Uso: $0 <TAG>" >&2
  exit 1
fi
if [[ "${TAG}" =~ [[:space:]] ]]; then
  echo "Tag invalido: contiene espacios (${TAG})" >&2
  exit 1
fi

# Docker/OCI no acepta '+' en tags; mantenemos el release tag en git
# y escribimos formato de imagen (sanitizado) en overlays.
IMAGE_TAG="${TAG//+/-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
KUSTOMIZATION_FILE="${REPO_ROOT}/devbox-app/gitops/overlays/minikube/kustomization.yaml"
BACKEND_IMAGE="ghcr.io/ihexhubs/devbox-app-backend"
FRONTEND_IMAGE="ghcr.io/ihexhubs/devbox-app-frontend"

[[ -f "${KUSTOMIZATION_FILE}" ]] || {
  echo "No existe ${KUSTOMIZATION_FILE}" >&2
  exit 1
}

if command -v yq >/dev/null 2>&1; then
  yq -i '
    (.images[] | select(.name == "'"${BACKEND_IMAGE}"'" or .newName == "'"${BACKEND_IMAGE}"'") | .newTag) = "'"${IMAGE_TAG}"'" |
    (.images[] | select(.name == "'"${FRONTEND_IMAGE}"'" or .newName == "'"${FRONTEND_IMAGE}"'") | .newTag) = "'"${IMAGE_TAG}"'"
  ' "${KUSTOMIZATION_FILE}"
else
  TMP_FILE="$(mktemp "${KUSTOMIZATION_FILE}.XXXXXX")"
  awk -v tag="${IMAGE_TAG}" \
      -v backend="${BACKEND_IMAGE}" \
      -v frontend="${FRONTEND_IMAGE}" '
    BEGIN { in_backend=0; in_frontend=0; backend_set=0; frontend_set=0 }
    /^[[:space:]]*-[[:space:]]*name:/ {
      in_backend=0
      in_frontend=0
    }
    /newName:[[:space:]]*/ || /name:[[:space:]]*/ {
      if ($0 ~ backend) { in_backend=1; in_frontend=0 }
      if ($0 ~ frontend) { in_frontend=1; in_backend=0 }
    }
    {
      line=$0
      if ($0 ~ /^[[:space:]]*newTag:[[:space:]]*/ && (in_backend || in_frontend)) {
        sub(/newTag:[[:space:]]*.*/, "newTag: " tag, line)
        if (in_backend) backend_set=1
        if (in_frontend) frontend_set=1
      }
      print line
    }
    END {
      if (!backend_set || !frontend_set) {
        exit 42
      }
    }
  ' "${KUSTOMIZATION_FILE}" > "${TMP_FILE}" || {
    rm -f "${TMP_FILE}"
    echo "No pude actualizar ambos newTag en ${KUSTOMIZATION_FILE}" >&2
    exit 1
  }
  mv "${TMP_FILE}" "${KUSTOMIZATION_FILE}"
fi

extract_tag() {
  local image="$1"
  awk -v image="${image}" '
    BEGIN { in_target=0 }
    /^[[:space:]]*-[[:space:]]*name:/ { in_target=0 }
    /newName:[[:space:]]*/ || /name:[[:space:]]*/ {
      if ($0 ~ image) in_target=1
    }
    in_target && /^[[:space:]]*newTag:[[:space:]]*/ {
      print $2
      exit
    }
  ' "${KUSTOMIZATION_FILE}"
}

BACKEND_TAG="$(extract_tag "${BACKEND_IMAGE}")"
FRONTEND_TAG="$(extract_tag "${FRONTEND_IMAGE}")"

[[ -n "${BACKEND_TAG}" ]] || {
  echo "No pude leer newTag de backend en ${KUSTOMIZATION_FILE}" >&2
  exit 1
}
[[ -n "${FRONTEND_TAG}" ]] || {
  echo "No pude leer newTag de frontend en ${KUSTOMIZATION_FILE}" >&2
  exit 1
}
[[ "${BACKEND_TAG}" == "${IMAGE_TAG}" ]] || {
  echo "Backend newTag no coincide: ${BACKEND_TAG} != ${IMAGE_TAG}" >&2
  exit 1
}
[[ "${FRONTEND_TAG}" == "${IMAGE_TAG}" ]] || {
  echo "Frontend newTag no coincide: ${FRONTEND_TAG} != ${IMAGE_TAG}" >&2
  exit 1
}
[[ "${BACKEND_TAG}" == "${FRONTEND_TAG}" ]] || {
  echo "Tags desalineados backend/frontend (${BACKEND_TAG} vs ${FRONTEND_TAG})" >&2
  exit 1
}

if [[ "${IMAGE_TAG}" != "${TAG}" ]]; then
  echo "OK: release tag aplicado en minikube overlay (${TAG} -> ${IMAGE_TAG})"
else
  echo "OK: release tag aplicado en minikube overlay (${IMAGE_TAG})"
fi
