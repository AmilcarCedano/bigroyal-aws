#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "Directorio actual (infra root): $(pwd)"
echo "Ejecutando Checkov..."

checkov --quiet

echo "Checkov finalizado."
