#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-dev}"
ACTION="${2:-plan}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT_DIR}/terraform/envs/${ENVIRONMENT}"

echo "Entorno: ${ENVIRONMENT}"
echo "Acción:  ${ACTION}"
echo "Carpeta: ${ENV_DIR}"

if [[ ! -d "${ENV_DIR}" ]]; then
  echo "ERROR: directorio de entorno no existe: ${ENV_DIR}" >&2
  exit 1
fi

cd "${ENV_DIR}"

echo "==== terraform init ===="
terraform init -input=false

echo "==== terraform validate ===="
terraform validate

TFVARS_ARG=()
if [[ -f "terraform.tfvars" ]]; then
  TFVARS_ARG=(-var-file="terraform.tfvars")
fi

case "${ACTION}" in
  plan)
    echo "==== terraform plan ===="
    terraform plan -input=false -out=tfplan "${TFVARS_ARG[@]}"
    ;;
  apply)
    if [[ -f tfplan ]]; then
      terraform apply -input=false tfplan
    else
      terraform plan -input=false -out=tfplan "${TFVARS_ARG[@]}"
      terraform apply -input=false tfplan
    fi
    ;;
  destroy)
    terraform destroy -input=false -auto-approve "${TFVARS_ARG[@]}"
    ;;
  *)
    echo "Acción no reconocida: ${ACTION}. Usa 'plan', 'apply' o 'destroy'."
    exit 1
    ;;
esac
