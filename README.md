# 🛡️ Enterprise SOC Lab — SIEM + SOAR + AI

> Laboratorio enterprise completo di Security Operations Center con detection, automazione della risposta agli incidenti e analisi AI locale delle vulnerabilità.

[![Wazuh](https://img.shields.io/badge/SIEM-Wazuh%204.14-005571)](https://wazuh.com)
[![n8n](https://img.shields.io/badge/SOAR-n8n-EA4B71)](https://n8n.io)
[![TheHive](https://img.shields.io/badge/IR-TheHive%205-FF6B00)](https://strangebee.com)
[![Ollama](https://img.shields.io/badge/AI-Llama%203-000000)](https://ollama.com)
[![Proxmox](https://img.shields.io/badge/Hypervisor-Proxmox%20VE-E57000)](https://proxmox.com)

---

## 📖 Overview

Questo repository raccoglie regole, workflow, script e documentazione di un progetto di laboratorio realizzato durante un Master in Cyber Security (LabForWeb — Regione Lazio, 2025-2026) presso un'azienda di servizi a Roma.

L'obiettivo era costruire da zero un'infrastruttura IT enterprise completa con SIEM/SOC funzionante, automazione della risposta agli incidenti (SOAR) e integrazione di un LLM locale per l'analisi automatizzata delle vulnerabilità — il tutto su hardware modesto e con software open source.

> **Nota:** Tutti i nomi utente, indirizzi email e riferimenti aziendali sono stati anonimizzati. Gli IP sono in subnet privata RFC1918.

---

## 🏗️ Architettura

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PROXMOX VE (Hypervisor)                     │
│                       192.168.173.0/24 — vmbr0                      │
└─────────────────────────────────────────────────────────────────────┘
        │                                                        │
        ▼                                                        ▼
┌──────────────────┐                                    ┌──────────────────┐
│ DOMINIO AD       │                                    │ SIEM / SOC ZONE  │
│ ─────────────    │                                    │ ─────────────    │
│ DC01 (.202)      │ ──── log/eventi ──────────────►    │ Wazuh Manager    │
│ DC02 (.203)      │                                    │ (.206) — VM 107  │
│ FILE01 (.204)    │ ──── FIM whodata ─────────────►    │                  │
│ Win11 Clients    │                                    │ OpenSearch       │
└──────────────────┘                                    │ Grafana (Kali)   │
        ▲                                               └────────┬─────────┘
        │                                                        │
        │ (replica)                                              │ webhook
        ▼                                                        ▼
┌──────────────────┐                                    ┌──────────────────┐
│ Proxmox Host     │ ──── syslog UDP:514 ──────────►    │ AUTOMAZIONE SOAR │
│ (.100) +         │                                    │ ─────────────    │
│ Wazuh agent      │      ┌───────────────────────►     │ n8n  (CT 102)    │
└──────────────────┘      │                             │ TheHive (CT 104) │
                          │                             │ Ollama (VM 108)  │
┌──────────────────┐      │                             │      │           │
│ Rsyslog (.208)   │ ─────┘                             │      ▼           │
│ VM 108           │                                    │ Email + Telegram │
└──────────────────┘                                    └──────────────────┘
```

**Stack tecnologico:**
- **Hypervisor**: Proxmox VE (KVM + LXC)
- **Identity**: Active Directory (Windows Server 2022) — dual-DC con replica
- **SIEM**: Wazuh 4.14.3 + OpenSearch
- **Dashboard**: Grafana 12.4 + plugin OpenSearch + Prometheus/Node Exporter
- **SOAR**: n8n (workflow automation) + TheHive 5 (incident response)
- **AI**: Ollama + Llama 3 (LLM locale per analisi CVE)
- **Notifiche**: SMTP + Telegram Bot API

---

## 🎯 Cosa contiene questo repo

### 📁 [`wazuh-rules/`](./wazuh-rules)
Le 12 regole di correlazione personalizzate per detection di:
- **Ransomware** comportamentale (creazione/cancellazione massive, rinomina con estensione anomala)
- **Brute force** Proxmox (MITRE ATT&CK T1110)
- **CRUD** su File Server con identità utente AD
- **Scenari di attacco** combinati (rule chaining)

### 📁 [`wazuh-decoders/`](./wazuh-decoders)
Decoder XML personalizzati per i log Proxmox `pvedaemon` (formato non standard con IPv4-mapped IPv6).

### 📁 [`n8n-workflows/`](./n8n-workflows)
Il workflow SOAR completo a 7 nodi: Webhook Wazuh → Switch (routing) → ramo Attacchi (TheHive + Email + Telegram) e ramo Vulnerabilità (Ollama AI + Telegram).

### 📁 [`scripts/`](./scripts)
- `custom-n8n.py` — script Python di integrazione Wazuh→n8n
- `test-bruteforce.sh` — simulazione brute force su Proxmox
- `test-ransomware.ps1` — simulazione ransomware su File Server

### 📁 [`grafana/`](./grafana)
- Query PromQL per pannelli hardware Proxmox (CPU, RAM, disco, uptime)
- Query Lucene per pannelli SOC su OpenSearch

### 📁 [`docs/`](./docs)
- `architecture.md` — schema completo della rete
- `troubleshooting.md` — problemi incontrati e soluzioni (cqlsh Ubuntu 25.04, Telegram parse mode, FIM whodata, ecc.)
- `lessons-learned.md` — 12 lezioni dal campo

---

## 🚀 Highlights del progetto

### 1. SIEM con detection ransomware comportamentale
Le regole 100030/100032/100044/100045/100046 implementano una detection chain per ransomware che non si basa su firme ma sul **comportamento**: cancellazioni massive, creazioni rapide, rinomina con cambio estensione. Funziona anche contro varianti zero-day.

### 2. SOAR end-to-end in <1 secondo
Dal momento in cui Wazuh rileva un brute force Proxmox al momento in cui l'analista SOC riceve la notifica Telegram con link diretto al caso TheHive, passa **meno di 1 secondo**. Tutto il flusso è automatizzato.

### 3. AI locale per l'analisi CVE (privacy-first)
Un nodo Ollama con Llama 3 riceve gli alert di vulnerabilità, genera un'analisi strutturata (rischio, comando di remediation, priorità) e la invia su Telegram. **Tutto in locale**, nessun dato esce dalla rete aziendale.

### 4. FIM whodata con identità AD reale
Il File Integrity Monitoring tracciar non solo il file modificato ma anche **l'utente AD** che ha eseguito l'operazione, sfruttando l'integrazione con Windows Security Audit (SACL + Event ID 4663).

---

## 📊 Numeri del progetto

| Metrica | Valore |
|---------|--------|
| Nodi virtualizzati | 11 (VM + LXC) |
| Agenti Wazuh attivi | 5 |
| Regole di correlazione custom | 12 |
| Decoder Wazuh personalizzati | 6 |
| Nodi workflow n8n | 7 |
| Pannelli dashboard Grafana | 18 |
| Test end-to-end superati | 30+ |
| Tempo di risposta SOAR | <1s |

---

## 🛠️ Come usare questo materiale

Questo repo **non** è un installer o un playbook automatizzato — è un portfolio tecnico che mostra le scelte progettuali, il codice e le configurazioni reali di un laboratorio funzionante. Se vuoi replicare l'infrastruttura:

1. Leggi [`docs/architecture.md`](./docs/architecture.md) per capire come si parlano i componenti
2. Adatta le regole Wazuh in [`wazuh-rules/`](./wazuh-rules) ai tuoi path e ai tuoi nomi agente
3. Importa il workflow n8n da [`n8n-workflows/wazuh-soar-workflow.json`](./n8n-workflows/) e ricrea le credenziali (TheHive API key, bot Telegram, SMTP)
4. Adatta le query PromQL/Lucene in [`grafana/`](./grafana) ai tuoi datasource

---

## 📚 Riferimenti

- **Articolo Medium**: *Building a SOAR pipeline with n8n, TheHive and a local LLM (Ollama + Llama 3)* — [link al pubblicato]
- **Wazuh Documentation**: https://documentation.wazuh.com
- **n8n Documentation**: https://docs.n8n.io
- **TheHive Documentation**: https://docs.strangebee.com
- **MITRE ATT&CK**: https://attack.mitre.org

---

## 📝 Licenza e disclaimer

- Codice e configurazioni rilasciati sotto licenza MIT (vedi `LICENSE`)
- Questo repo è materiale **didattico/portfolio**: le configurazioni di sicurezza (es. `network.host: 0.0.0.0` su OpenSearch, `OLLAMA_HOST=0.0.0.0`) sono adatte solo a un laboratorio in rete privata. Per uso in produzione vanno irrobustite.
- Tutti i riferimenti aziendali sono stati anonimizzati nel rispetto degli accordi di riservatezza.

---

## 👤 Autore

Progetto realizzato nell'ambito del Master in Cyber Security — LabForWeb / Regione Lazio (2025-2026).

Connect on LinkedIn: [linkedin.com/in/d-gabriel-stanciu](https://linkedin.com/in/d-gabriel-stanciu)

---

⭐ Se questo materiale ti è stato utile, lascia una stella al repository!
