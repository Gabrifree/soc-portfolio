#!/bin/bash
#
# test-bruteforce.sh
# ==================
# Simulazione brute force su interfaccia HTTPS Proxmox VE (porta 8006).
# Validazione delle regole Wazuh 100015 (singolo fail) e 100501 (brute force).
#
# USO ESCLUSIVAMENTE IN AMBIENTE DI LABORATORIO CONTROLLATO.
#
# Requisiti: curl
#
# Uso:
#   ./test-bruteforce.sh [PROXMOX_IP] [ATTEMPTS]
#
# Default: 192.168.173.100, 15 tentativi
#

set -e

PROXMOX_IP="${1:-192.168.173.100}"
ATTEMPTS="${2:-15}"
URL="https://${PROXMOX_IP}:8006/api2/json/access/ticket"

echo "==================================================="
echo "  TEST BRUTE FORCE — Proxmox HTTPS"
echo "==================================================="
echo "  Target  : ${URL}"
echo "  Attempts: ${ATTEMPTS}"
echo "==================================================="
echo ""

# Verifica che curl sia disponibile
if ! command -v curl >/dev/null 2>&1; then
    echo "ERRORE: curl non installato. apt install curl"
    exit 1
fi

# Loop di tentativi falliti
for i in $(seq 1 "$ATTEMPTS"); do
    USER="fakeuser${i}@pam"
    PASS="WrongPass${i}!"

    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
        --max-time 5 \
        --data-urlencode "username=${USER}" \
        --data-urlencode "password=${PASS}" \
        "${URL}" 2>/dev/null || echo "000")

    printf "[%2d/%d] %s → HTTP %s\n" "$i" "$ATTEMPTS" "$USER" "$HTTP_CODE"

    # Pausa minima tra tentativi (regola 100501 cerca 10+ in 2 secondi)
    sleep 0.1
done

echo ""
echo "==================================================="
echo "  Test completato."
echo "==================================================="
echo ""
echo "Verifica gli alert sulla Wazuh Dashboard:"
echo "  - Rule 100015 (Login fallito singolo) : atteso ${ATTEMPTS} alert Lv5"
echo "  - Rule 100501 (Brute Force MITRE T1110): atteso 1+ alert Lv12"
echo ""
echo "Verifica il workflow n8n SOAR:"
echo "  - Caso creato su TheHive con severita' Critical"
echo "  - Email inviata all'account SOC"
echo "  - Notifica Telegram con emoji rossa"
