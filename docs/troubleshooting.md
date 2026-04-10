# Troubleshooting — problemi reali incontrati e soluzioni

Questa è la collezione dei problemi più "tosti" incontrati durante il progetto, con le soluzioni effettivamente applicate. Sono i pezzi più utili del repo per chi vuole replicare l'infrastruttura e cerca su Google quando qualcosa non va.

---

## 1. cqlsh fallisce su Ubuntu 25.04 con `ModuleNotFoundError: six.moves`

### Sintomo
```
$ cqlsh -e "DROP KEYSPACE thehive;"
Traceback (most recent call last):
  File "/usr/bin/cqlsh.py", line 134, in <module>
    from cassandra.cluster import Cluster
  File "/usr/share/cassandra/lib/cassandra-driver-internal-only-3.25.0.zip/...
    from six.moves import filter, range, queue as Queue
ModuleNotFoundError: No module named 'six.moves'
```

### Causa radice
`cqlsh` carica il proprio driver Cassandra da un file ZIP isolato (`cassandra-driver-internal-only-3.25.0.zip`) che **non legge**:
- i pacchetti Python del sistema (`apt install python3-six` non aiuta)
- il `PYTHONPATH` di sistema (ignorato dal loader ZIP interno)
- `pip install` a livello sistema (dirà "already satisfied" ma cqlsh continua a non vederlo)

Ubuntu 25.04 include Python 3.13, incompatibile con il driver legacy nello ZIP.

### Tentativi falliti
1. `apt install python3-six` → ZIP isolato, non lo vede
2. `PYTHONPATH=/usr/lib/python3/dist-packages cqlsh ...` → ignorato
3. `pip3 install six --break-system-packages` → "already satisfied"

### Soluzione definitiva
Saltare completamente `cqlsh` e usare il driver Python direttamente:

```bash
# Installazione driver Cassandra fresco
pip3 install cassandra-driver --break-system-packages

# Esecuzione DROP KEYSPACE direttamente da Python
python3 -c "
from cassandra.cluster import Cluster
cluster = Cluster(['127.0.0.1'])
session = cluster.connect()
session.execute('DROP KEYSPACE IF EXISTS thehive')
print('Keyspace eliminato correttamente')
cluster.shutdown()
"
```

**Perché funziona:** `pip` installa in `/usr/local/lib/python3.x/dist-packages` che il Python di sistema trova normalmente, a differenza del loader ZIP di cqlsh.

**Lezione:** in produzione usare sempre **Ubuntu 22.04 LTS** o **20.04 LTS** per TheHive/Cassandra/Elasticsearch. Le release non-LTS introducono librerie Python incompatibili con il codice legacy.

---

## 2. Telegram errore 400 "can't parse entities"

### Sintomo
Il nodo Telegram di n8n nel ramo Ollama fallisce con:
```
400 - {"ok":false,"error_code":400,
"description":"Bad Request: can't parse entities:
Can't find end of the entity starting at byte offset 222"}
```

### Causa
Il modello Llama 3 genera testo con caratteri Markdown (`*`, `_`, `[`) che Telegram in modalità Markdown non riesce a chiudere correttamente, producendo entità malformate.

### Soluzione
1. Cambiare **Parse Mode = HTML** nel nodo Telegram (NON Markdown)
2. Usare `<b>`, `<i>`, `<a href="...">` invece di `*bold*`, `_italic_`, `[testo](url)`
3. Accedere all'output di Ollama con `{{ $json.content }}` (non `$json.message.content` come suggeriscono alcuni esempi datati)

```html
<b>🤖 ANALISI AI (Ollama):</b>
{{ $json.content }}
```

---

## 3. Wazuh FIM whodata non cattura l'identità AD

### Sintomo
Il campo `syscheck.uname_after` è vuoto o contiene `NT AUTHORITY\SYSTEM` invece dell'utente AD reale.

### Causa
La modalità whodata richiede **TUTTI** i prerequisiti Windows Security Auditing abilitati. Manca tipicamente:
- "Audit Handle Manipulation" (Controlla manipolazione handle) → senza questo il driver kernel di Wazuh non riesce ad associare l'handle del file aperto all'identità utente

### Soluzione
Su FILE01 in `secpol.msc`:

1. **Local Policies → Audit Policy → Object Access**
   - Audit Object Access: **Success, Failure**
   - Audit Handle Manipulation: **Success, Failure** ← critico!

2. **SACL sulla cartella** `C:\ProjectData\` → tab Security → Advanced → Auditing
   - Aggiungere "Authenticated Users"
   - Tipo: "All"
   - Si applica a: "This folder, subfolders and files"
   - Operazioni: spuntare tutte (Full Control)

3. Riavviare il Wazuh Agent: `Restart-Service WazuhSvc`

4. Verificare che gli Event ID 4663 (Object Access) compaiono in Event Viewer → Security

**Bonus:** per le query Grafana usare **`syscheck.uname_after`** (campo flat) e NON `syscheck.audit.user.name` (annidato, richiede dot notation speciale).

---

## 4. Ollama non raggiungibile dalla rete

### Sintomo
Da n8n (CT 102) la chiamata a `http://192.168.173.208:11434` va in timeout, ma da localhost sull'host Ollama funziona.

### Causa
Di default Ollama ascolta solo su `127.0.0.1`. Per renderlo raggiungibile dalla LAN serve un override systemd.

### Soluzione
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo nano /etc/systemd/system/ollama.service.d/override.conf
```

Contenuto (**solo queste due righe, nient'altro!**):
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Applicare:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
systemctl status ollama
# Deve mostrare "Listening on [::]:11434" (NON 127.0.0.1!)
```

Verifica da un'altra macchina:
```bash
curl http://192.168.173.208:11434
# Output atteso: "Ollama is running"
```

**Nota produzione:** in produzione **NON** usare `0.0.0.0`. Limitare con firewall/UFW al solo IP del client n8n.

---

## 5. Decoder Wazuh Proxmox non vengono caricati

### Sintomo
Le regole basate su `<decoded_as>proxmox-auth</decoded_as>` non scattano mai, anche se i log arrivano correttamente nel Wazuh Manager.

### Causa
Wazuh carica i file decoder in **ordine alfabetico**. Un decoder figlio (con `<parent>`) deve trovarsi in un file caricato **dopo** il file che definisce il padre. Se il decoder padre è in `proxmox.xml` e il figlio in `aaa-proxmox.xml`, il figlio viene caricato prima del padre e fallisce silenziosamente.

### Soluzione
**Sicurezza massima:** mettere TUTTI i decoder personalizzati in **`local_decoder.xml`** (file standard Wazuh, già caricato per ultimo nell'ordine alfabetico nella maggior parte delle distribuzioni).

In alternativa, nominare i file con prefissi numerici crescenti:
- `01_proxmox_parent.xml`
- `02_proxmox_fields.xml`

Verifica caricamento:
```bash
/var/ossec/bin/wazuh-logtest
# Incollare un log di test e vedere se i decoder vengono applicati
```

---

## 6. Wazuh `frequency="1"` causa errore di parsing XML silenzioso

### Sintomo
Dopo aver aggiunto una regola con `frequency="1"`, al riavvio del Wazuh Manager le regole custom smettono di funzionare. Nessun errore visibile in dashboard.

### Causa
Il valore minimo per `frequency` nelle regole di correlazione Wazuh è **`2`**. Il valore `1` causa un errore di parsing XML silenzioso che blocca tutto il file di regole.

### Soluzione
Usare sempre `frequency="2"` come minimo. Se serve un singolo evento, non usare `frequency` affatto:

```xml
<!-- SBAGLIATO -->
<rule id="100099" level="5" frequency="1" timeframe="60">
  <if_sid>554</if_sid>
  ...
</rule>

<!-- CORRETTO -->
<rule id="100099" level="5">
  <if_sid>554</if_sid>
  ...
</rule>
```

**Diagnostica:** controllare `tail -f /var/ossec/logs/ossec.log` mentre si riavvia il manager.

---

## 7. Wazuh password admin: la GUI non basta

### Sintomo
Dopo aver cambiato la password admin di Wazuh dalla dashboard web, Filebeat smette di funzionare e gli alert non arrivano più in OpenSearch.

### Causa
La GUI aggiorna **solo il database interno** di OpenSearch lasciando tutti i servizi dipendenti (Filebeat, Wazuh Dashboard, Wazuh API) con le credenziali vecchie.

### Soluzione
Usare **sempre** lo script ufficiale:

```bash
sudo /var/ossec/bin/wazuh-passwords-tool.sh -u admin -p NUOVAPASSWORD
```

Lo script aggiorna in cascata: keystore di Filebeat, configurazione Dashboard, internal_users.yml di OpenSearch.

Dopo:
```bash
sudo systemctl restart filebeat wazuh-manager wazuh-dashboard
```

---

## 8. GPO MapDrive fallisce silenziosamente sulle nuove workstation

### Sintomo
Le workstation appena joinate al dominio non hanno l'unità Z: mappata, anche dopo `gpupdate /force`.

### Causa
La GPO Drive Mapping è stata creata con azione **"Update"** invece di **"Replace"**. L'azione Update tenta di aggiornare un mapping esistente — ma sulle workstation nuove non c'è ancora nulla da aggiornare, quindi fallisce silenziosamente senza creare il mapping.

### Soluzione
**Sempre `Replace`** per il drive mapping, non `Update`. Replace cancella il mapping esistente (se c'è) e ne crea uno nuovo, funzionando in entrambi gli scenari (workstation esistente e workstation nuova).

In `gpmc.msc` → User Configuration → Preferences → Windows Settings → Drive Maps → Properties → Action: **Replace**.
