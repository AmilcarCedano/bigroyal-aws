#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}/terraform"

echo "Directorio actual (Terraform root): $(pwd)"
echo "Ejecutando Checkov..."

checkov -d . --quiet --soft-fail

echo "Checkov finalizado."
