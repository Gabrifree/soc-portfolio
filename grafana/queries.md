# Grafana queries reference

Tutte le query utilizzate nei pannelli della dashboard SOC, divise per datasource.

## Datasource 1 — Prometheus (metriche hardware Proxmox)

URL: `http://192.168.173.208:9090`
Scrape target: `192.168.173.100:9100` (Node Exporter sull'host Proxmox)

### CPU Proxmox (Gauge)

```promql
100 - (avg by(instance)(irate(
  node_cpu_seconds_total{instance="192.168.173.100:9100",mode="idle"}[15s]
)) * 100)
```

**Spiegazione:** `node_cpu_seconds_total` conta i secondi CPU per ogni modalità. `irate()` calcola il tasso istantaneo di variazione negli ultimi 15 secondi. Si prende il tempo "idle" (CPU inattiva) e si sottrae da 100 per ottenere la percentuale di utilizzo effettivo.

**Configurazione pannello:**
- Unit: `Percent (0-100)`
- Min: 0, Max: 100
- Thresholds: 0=Verde, 70=Giallo, 90=Rosso

---

### RAM Proxmox (Gauge)

```promql
100 * (1 - (
  (node_memory_MemFree_bytes{instance="192.168.173.100:9100"}
   + node_memory_Cached_bytes{instance="192.168.173.100:9100"}
   + node_memory_Buffers_bytes{instance="192.168.173.100:9100"})
  / node_memory_MemTotal_bytes{instance="192.168.173.100:9100"}
))
```

**Spiegazione:** Linux usa la RAM libera come cache per velocizzare il disco. Cache e buffer vengono rilasciati immediatamente se un processo ne ha bisogno, quindi non vanno contati come "occupati". La formula sottrae RAM libera + cache + buffer dal totale per ottenere l'utilizzo reale (compatibile con `free -m`).

**Configurazione pannello:**
- Unit: `Percent (0-100)`
- Thresholds: 0=Verde, 80=Giallo, 90=Rosso

---

### Disco Proxmox / (Gauge)

```promql
100 - (
  (node_filesystem_avail_bytes{instance="192.168.173.100:9100",mountpoint="/"}
   * 100)
  / node_filesystem_size_bytes{instance="192.168.173.100:9100",mountpoint="/"}
)
```

**Spiegazione:** percentuale di spazio occupato sulla partizione root. `avail` è lo spazio disponibile, `size` è il totale.

**Configurazione pannello:**
- Unit: `Percent (0-100)`
- Thresholds: 0=Verde, 75=Giallo, 90=Rosso

---

### Uptime Proxmox (Stat)

```promql
node_time_seconds{instance="192.168.173.100:9100"}
- node_boot_time_seconds{instance="192.168.173.100:9100"}
```

**Spiegazione:** differenza tra timestamp Unix attuale e timestamp di boot.

**Configurazione pannello:**
- Unit: `dtdhms` (giorni:ore:minuti:secondi)
- Color: fisso Blu

---

## Datasource 2 — OpenSearch (alert e log Wazuh)

URL: `https://192.168.173.206:9200`
Index pattern: `wazuh-alerts-*`

### Stat — Attacco di Massa (rule 100046)

```lucene
rule.id:100046
```

Time: `Last 24h` | Calculation: `Count`
Thresholds: 0=Verde, 1=Rosso scuro

### Stat — Ransomware Cifratura (rule 100032)

```lucene
rule.id:100032
```

Time: `Last 24h` | Calculation: `Count`
Thresholds: 0=Verde, 1=Rosso

### Stat — Login Falliti AD (Event 4625)

```lucene
data.win.system.eventID:4625 AND agent.name:DC01
```

Time: `Last 24h` | Calculation: `Count`
Thresholds: 0=Verde, 5=Giallo, 15=Rosso

### Stat — Brute Force Proxmox (rule 100501)

```lucene
rule.id:100501
```

Time: `Last 24h` | Calculation: `Count`
Thresholds: 0=Verde, 1=Rosso

---

### Pie Chart — Distribuzione operazioni FIM su ProjectData

3 query separate, una per fetta:

**Creazione:**
```lucene
rule.id:100041
```

**Modifica:**
```lucene
rule.id:100042
```

**Cancellazione:**
```lucene
rule.id:100043
```

Calculation: **`Sum`** (NON `Last *` — Last prende solo l'ultimo bucket che è spesso 0 e svuota il pannello).
Colori: Creazione=Verde, Modifica=Arancio, Cancellazione=Rosso.

---

### Bar Chart — Top utenti per operazioni FIM

```lucene
syscheck.path:C\:\\\\ProjectData\\\\*
```

Group by: `syscheck.uname_after.keyword` (Top 10)

> **Nota:** usare `syscheck.uname_after` (campo flat) e NON `syscheck.audit.user.name` (annidato, richiede dot notation speciale in Lucene).

---

### Bar Chart — Top IP sorgente login falliti AD

```lucene
data.win.system.eventID:4625
```

Group by: `data.win.eventdata.ipAddress.keyword` (Top 5)

---

### Tabella — Log dettaglio AD (raw_data)

```lucene
data.win.system.eventID:(4625 OR 4720 OR 4722 OR 4738 OR 4740)
```

Trasformazione **Organize fields**: nascondere tutti i campi tecnici (`_id`, `_index`, `agent.id`, ecc.), mostrare solo:
- `@timestamp`
- `data.win.system.eventID` (con Value Mapping: 4625→"Login Fallito", 4740→"Account Bloccato", ecc.)
- `data.win.eventdata.targetUserName`
- `data.win.eventdata.ipAddress`
- `data.win.eventdata.workstationName`
- `data.win.system.message`

---

## Alerting nativo Grafana

### Alert: Ransomware Critical
**Condition:** count(rule.id:100046) > 0 nell'ultimo 1m
**Frequency:** ogni 30s
**Notification:** webhook → n8n (lo stesso usato da Wazuh)

### Alert: Brute Force Proxmox
**Condition:** count(rule.id:100501) > 0 nell'ultimo 1m
**Frequency:** ogni 30s

> **Nota architetturale:** l'alerting Grafana è ridondante rispetto al webhook Wazuh, ma utile come fallback se il manager Wazuh ha problemi di rete o di restart.
