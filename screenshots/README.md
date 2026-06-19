# Screenshots

Immagini dell'infrastruttura SOC operativa. Tutti gli identificativi sensibili (email, ID mailbox) sono stati oscurati; gli IP sono in subnet privata RFC1918.

| File | Contenuto |
|------|-----------|
| `01_proxmox_overview.png` | Vista ad albero del datacenter Proxmox con tutti i nodi (VM e container LXC) |
| `02_wazuh_dashboard_agents.png` | I 5 agenti Wazuh in stato Active (3 Windows + 1 Ubuntu + 1 Debian) |
| `03_grafana_soc_dashboard.png` | Dashboard SOC su Grafana — monitoraggio VM Proxmox su 7 giorni |
| `04_n8n_workflow_final.png` | Workflow SOAR n8n pubblicato (Webhook → TheHive) |
| `05_thehive_cases.png` | Lista casi su TheHive generati automaticamente dal workflow |
| `06_email_alert.png` | Notifica email automatica generata da n8n (mittente oscurato) |
| `07_grafana_hardware_gauges.png` | Gauge hardware Proxmox (CPU/RAM/Disco/Uptime) da Prometheus |
| `08_wazuh_rules.png` | Le 12 regole di correlazione custom nella dashboard Wazuh |
| `09_wazuh_decoders.png` | I 6 decoder personalizzati per i log Proxmox |
