#!/usr/bin/env python3
"""
custom-n8n
==========
Wazuh → n8n integration script.

Wazuh chiama questo script ogni volta che un alert matcha le rule_id
configurate nel blocco <integration> di ossec.conf. Lo script legge il
JSON dell'alert e lo inoltra al webhook n8n.

INSTALLAZIONE:
    1. Copiare in /var/ossec/integrations/custom-n8n
    2. chmod 750 /var/ossec/integrations/custom-n8n
    3. chown root:wazuh /var/ossec/integrations/custom-n8n
    4. Aggiungere il blocco <integration> in /var/ossec/etc/ossec.conf
    5. systemctl restart wazuh-manager

CONFIGURAZIONE in ossec.conf:
    <integration>
        <name>custom-n8n</name>
        <hook_url>http://192.168.173.210:5678/webhook/wazuh-alert</hook_url>
        <rule_id>100030,100032,100044,100045,100046,100501</rule_id>
        <alert_format>json</alert_format>
    </integration>

ARGOMENTI passati da Wazuh:
    sys.argv[1] = path al file JSON dell'alert
    sys.argv[2] = api_key (vuoto se non usato)
    sys.argv[3] = hook_url (l'URL del webhook n8n)
    sys.argv[4] = (opzionale) options
"""

import sys
import json
import urllib.request
import urllib.error
import logging

# Logging in /var/ossec/logs/integrations.log
logging.basicConfig(
    filename="/var/ossec/logs/integrations.log",
    level=logging.INFO,
    format="%(asctime)s [custom-n8n] %(levelname)s: %(message)s"
)


def send_to_n8n(alert_file: str, webhook_url: str) -> int:
    """Legge l'alert e lo invia al webhook n8n via POST. Ritorna l'exit code."""
    try:
        with open(alert_file, "r", encoding="utf-8") as f:
            alert = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logging.error(f"Impossibile leggere l'alert {alert_file}: {e}")
        return 1

    # Estrazione campi minimi per il logging
    rule_id = alert.get("rule", {}).get("id", "n/a")
    rule_desc = alert.get("rule", {}).get("description", "n/a")
    agent_name = alert.get("agent", {}).get("name", "n/a")

    payload = json.dumps(alert).encode("utf-8")
    request = urllib.request.Request(
        webhook_url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Wazuh-Custom-Integration/1.0",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            status = response.status
            logging.info(
                f"Alert inviato OK (rule {rule_id}, agent {agent_name}, "
                f"status HTTP {status}): {rule_desc}"
            )
            return 0
    except urllib.error.HTTPError as e:
        logging.error(
            f"HTTP error {e.code} per rule {rule_id}: {e.reason}"
        )
        return 1
    except urllib.error.URLError as e:
        logging.error(
            f"Connessione fallita a {webhook_url} per rule {rule_id}: {e.reason}"
        )
        return 1
    except Exception as e:
        logging.exception(f"Errore inatteso: {e}")
        return 1


def main(argv: list) -> int:
    if len(argv) < 4:
        logging.error(
            f"Argomenti insufficienti. Ricevuti {len(argv)}, "
            f"attesi almeno 4. argv={argv}"
        )
        return 1

    alert_file = argv[1]
    # argv[2] e' l'api_key, non usata
    webhook_url = argv[3]

    return send_to_n8n(alert_file, webhook_url)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
