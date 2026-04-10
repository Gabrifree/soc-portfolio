# Lezioni apprese dal progetto

Le 12 lezioni più importanti del progetto, in ordine di rilevanza pratica.

## 1. Snapshot Proxmox prima di TUTTO

Il rollback di uno snapshot richiede 30 secondi e salva ore di troubleshooting. Non c'è giustificazione per non farlo prima di ogni operazione critica (promozione DC, modifica regole Wazuh, aggiornamenti, ecc.). Durante il progetto è stato applicato sistematicamente e ha salvato il setup almeno 3 volte.

## 2. Ubuntu non-LTS è una trappola per il software enterprise

Ubuntu 25.04 ha rotto Cassandra/Elasticsearch/TheHive a causa di Python 3.13. **Per installazioni enterprise usare sempre release LTS** (20.04, 22.04, 24.04). Le versioni intermedie introducono librerie aggiornate incompatibili con il codice legacy che troverai in molti software enterprise.

## 3. Sensore vs Bersaglio nel SIEM

Quando Proxmox invia i log via syslog a un collector, Wazuh identifica come "agente" il **collettore** (rsyslogserver), non il bersaglio reale (Proxmox). In ambienti con log forwarding è necessario disambiguare i due ruoli **nella description degli alert** e nei casi TheHive — altrimenti l'analista vede sempre lo stesso "agente sospetto" e non capisce cosa è successo.

## 4. FIM whodata richiede TUTTI i prerequisiti

Senza "Audit Handle Manipulation" in `secpol.msc` il driver kernel di Wazuh non riesce ad associare l'handle del file aperto all'identità AD. Il campo `syscheck.uname_after` è più affidabile di `syscheck.audit.user.name` per le query Grafana (campo flat vs annidato).

## 5. `frequency="1"` non esiste in Wazuh

Il valore minimo per `frequency` nelle regole di correlazione è `2`. `frequency="1"` causa errore di parsing XML silenzioso al riavvio del manager — diagnosticabile solo leggendo `/var/ossec/logs/ossec.log`.

## 6. L'ordine alfabetico dei file decoder Wazuh è determinante

Un decoder figlio (con `<parent>`) deve trovarsi in un file caricato **dopo** il file del padre. La soluzione più sicura è mettere tutti i decoder personalizzati in coda a `local_decoder.xml`.

## 7. GPO MapDrive: usare SEMPRE "Replace" non "Update"

L'azione "Update" fallisce silenziosamente sulle workstation nuove che non hanno ancora un'unità Z: esistente da aggiornare.

## 8. Le credenziali Wazuh richiedono lo script ufficiale

Per cambiare la password admin di Wazuh/OpenSearch è obbligatorio usare `wazuh-passwords-tool.sh`. La GUI aggiorna solo il database interno di OpenSearch lasciando Filebeat, Dashboard e API con le credenziali vecchie.

## 9. cqlsh ha un ambiente Python isolato

Il driver ZIP interno di cqlsh ignora `PYTHONPATH`, `apt install` e `pip install` a livello di sistema. La soluzione è installare un driver Cassandra separato tramite `pip install --break-system-packages` ed eseguire le query direttamente con `python3 -c "..."`.

## 10. Il troubleshooting sistematico supera il trial-and-error

Nel caso del bug cqlsh, **leggere il traceback Python riga per riga** ha permesso di identificare il percorso esatto del file ZIP incriminato e capire perché PYTHONPATH non poteva funzionare — portando alla soluzione in un singolo passaggio. Stessa lezione per il bug Telegram 400: **leggere l'errore esatto** ("can't parse entities at byte offset 222") indicava chiaramente un problema di parsing Markdown.

## 11. Telegram con LLM = sempre Parse Mode HTML

I modelli LLM generano testo con caratteri Markdown (`*`, `_`, `[`) che rompono il parser Telegram in modalità Markdown. Usare sempre **HTML mode** con tag `<b>`, `<i>`, `<a href>`. Vale per qualsiasi pipeline che mette LLM e Telegram in serie.

## 12. Pie Chart Grafana con Date Histogram: Calculation = Sum

Il default "Last *" prende solo l'ultimo bucket temporale che è spesso 0, rendendo il pannello vuoto nonostante i dati siano presenti nell'indice. Usare sempre **Sum** per i pie chart su dati aggregati nel tempo.

---

## Bonus — La tabella `raw_data` di Grafana porta TUTTI i campi OpenSearch

50+ colonne di rumore tecnico (`_id`, `_index`, `agent.id`, ecc.). Usare sempre la trasformazione **"Organize fields"** per selezionare e rinominare solo le colonne utili. Combinato con **Value Mappings** colorati sui campi rilevanti (es. Event ID → "Login Fallito" su sfondo rosso) si ottiene un pannello SOC professionale leggibile in 1 secondo.
