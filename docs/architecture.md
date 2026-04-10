# Architettura del laboratorio SOC

## 1. Tabella IP completa

| Host | IP | Ruolo | OS |
|------|------|-------|-----|
| pve | 192.168.173.100 | Hypervisor Proxmox + Wazuh agent | Debian 13 |
| DC01 | 192.168.173.202 | Primary Domain Controller, DNS, DHCP | Win Server 2022 |
| DC02 | 192.168.173.203 | Additional Domain Controller, DNS replica | Win Server 2022 |
| FILE01 | 192.168.173.204 | File Server (ProjectData) + FIM whodata | Win Server 2022 |
| Wazuh Manager | 192.168.173.206 | SIEM core (VM 107) | Ubuntu 22.04 |
| Rsyslog | 192.168.173.208 | Syslog collector + Prometheus + Ollama (VM 108) | Debian Linux |
| n8n | 192.168.173.210 | SOAR workflow engine (CT 102) | Ubuntu 22.04 LTS |
| TheHive | 192.168.173.211 | Incident Response (CT 104) | Ubuntu 25.04 |
| Kali | DHCP | Grafana SOC dashboard | Kali Rolling |
| SOC-01 | 192.168.173.111 | Postazione analista (utente1) | Win 11 |
| SOC-02 | 192.168.173.146 | Postazione analista (utente2) | Win 11 |
| SOC-03 | 192.168.173.102 | Postazione analista (utente3) | Win 11 |

## 2. Pipeline dei log

```
┌──────────────────────────────────────────────────────────────────┐
│  PIPELINE 1 — Eventi Windows (DC01, FILE01, postazioni SOC)       │
└──────────────────────────────────────────────────────────────────┘

   [Windows Event Log]
          │
          ▼  Wazuh Agent (TCP 1514, AES)
   [Wazuh Manager VM 107]
          │
          ├─ analysis: regole + decoder
          ├─ filebeat → OpenSearch (HTTPS 9200)
          │
          └─ integration → custom-n8n.py → webhook n8n


┌──────────────────────────────────────────────────────────────────┐
│  PIPELINE 2 — Log Proxmox (host fisico)                            │
└──────────────────────────────────────────────────────────────────┘

   [Proxmox VE pvedaemon] ───► syslog UDP:514 ───► [Rsyslog VM 108]
                                                          │
                                                          ▼
                                                  /var/log/syslog
                                                          │
                                                          ▼  Wazuh Agent
                                                  [Wazuh Manager]
                                                          │
                                          decoder proxmox-auth
                                          rule 100015 / 100501
                                                          │
                                                          ▼
                                                    [OpenSearch]


┌──────────────────────────────────────────────────────────────────┐
│  PIPELINE 3 — Hardware metrics                                     │
└──────────────────────────────────────────────────────────────────┘

   [Node Exporter on Proxmox host :9100]
          ▲
          │  scrape ogni 15s
          │
   [Prometheus VM 108 :9090]
          ▲
          │  query PromQL
          │
   [Grafana Kali :3000]
          ▲
          │
       browser
```

## 3. Pipeline SOAR

```
                    Wazuh detection (rule fires)
                              │
                              ▼
                  custom-n8n.py (integration script)
                              │
                              │  HTTP POST JSON
                              ▼
                  ┌──────────────────────┐
                  │  n8n Webhook         │
                  │  (CT 102 — :5678)    │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │  Switch (mode: rules)│
                  └─────┬───────────┬────┘
                        │           │
              attacchi  │           │  vulnerabilità
                        ▼           ▼
        ┌───────────────────┐   ┌───────────────────┐
        │  TheHive 5        │   │  Ollama (Llama 3) │
        │  Create alert     │   │  AI analysis      │
        │  (CT 104 — :9000) │   │  (VM 108 — :11434)│
        └─────────┬─────────┘   └─────────┬─────────┘
                  │                        │
          ┌───────┴───────┐                ▼
          ▼               ▼      ┌───────────────────┐
   ┌──────────┐   ┌───────────┐  │  Telegram Bot     │
   │  SMTP    │   │  Telegram │  │  (HTML mode)      │
   │  Email   │   │  Bot      │  └───────────────────┘
   └──────────┘   └───────────┘
```

## 4. Componenti FIM

| Host | Cartella | Modalità | Note |
|------|----------|----------|------|
| FILE01 | `C:\ProjectData\` | whodata | Identità AD reale via Win Audit |
| SOC-02 | `C:\Users\utente2\Desktop\StageCondivisa` | realtime | Notifiche kernel istantanee |

**Prerequisiti whodata su FILE01:**
- `secpol.msc` → Audit Object Access: Success/Failure
- `secpol.msc` → Audit Handle Manipulation: Success/Failure
- SACL su `C:\ProjectData\` per "Authenticated Users" → tutte le operazioni

## 5. Numero porte aperte

| Porta | Protocollo | Servizio | Host |
|------|------|------|------|
| 22 | TCP | SSH | tutti i Linux |
| 80 | TCP | HTTP (Telegram Bot API in uscita) | n8n CT |
| 443 | TCP | HTTPS (TheHive API, Ollama API in uscita) | n8n CT |
| 514 | UDP | Syslog | Rsyslog VM 108 |
| 1514 | TCP | Wazuh Agent | Wazuh Manager |
| 1515 | TCP | Wazuh Enrollment | Wazuh Manager |
| 3000 | TCP | Grafana | Kali |
| 5678 | TCP | n8n web UI + webhook | n8n CT |
| 8006 | TCP/HTTPS | Proxmox Web UI | Proxmox host |
| 9000 | TCP | TheHive web UI | TheHive CT |
| 9090 | TCP | Prometheus | VM 108 |
| 9100 | TCP | Node Exporter | Proxmox host |
| 9200 | TCP/HTTPS | OpenSearch API | Wazuh Manager |
| 11434 | TCP | Ollama API | VM 108 |
