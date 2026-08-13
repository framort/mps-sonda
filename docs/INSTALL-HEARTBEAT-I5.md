# Installazione heartbeat sull'i5 — dead-man's switch (issue #3)

Questo documento descrive come attivare l'heartbeat sull'i5. **Nessuna
azione qui e' stata eseguita automaticamente**: nessun commit di questo
repo tocca l'i5. L'installazione la fa Francesco, a mano, quando decide di
autorizzarla.

## Perche' serve

`probe-i5.yml` chiede "sei vivo?" a `app.mp-platform.com` e
`cam.mp-platform.com`. Quei domini stanno dietro Cloudflare Access, che
risponde `302` dal proprio edge **senza mai contattare l'i5** — anche a
casa senza corrente (prova: blackout 12/08, run #446 ha stampato OK a
47 secondi dal blackout). Quel controllo strutturalmente non puo' vedere
un guasto totale.

`heartbeat-check.yml` (gia' nel repo, gia' schedulato) risolve il problema
al contrario: invece di chiedere "sei vivo?" a chi risponde sempre di si',
aspetta un segnale che solo l'i5 puo' produrre. Finche' questo script non
e' installato, quel segnale non esiste, e la sonda lo dice onestamente
(vedi "Cosa succede se non installi subito" sotto).

## Cosa fa lo script

Ogni volta che gira, `i5/heartbeat-publish.sh` manda un piccolo POST a
`ntfy.sh` su un topic dedicato, **senza passare dal tunnel Cloudflare ne'
dai domini app/cam**. Prova solo che l'i5 ha corrente e una via d'uscita a
internet — nient'altro.

## Passi

1. **Copiare lo script sull'i5** (accesso via Tailscale, come sempre):
   ```
   scp i5/heartbeat-publish.sh root@100.107.25.4:/usr/local/bin/heartbeat-publish.sh
   ssh root@100.107.25.4 chmod +x /usr/local/bin/heartbeat-publish.sh
   ```

2. **Creare `/etc/mps-heartbeat.conf`** sull'i5 con una riga:
   ```
   NTFY_TOPIC_BASE="<stesso valore del secret GitHub NTFY_TOPIC del repo framort/mps-sonda>"
   ```
   Il valore **deve essere identico** al secret GitHub `NTFY_TOPIC` gia'
   configurato su questo repo (Settings → Secrets → Actions, il valore non
   e' leggibile da li', ma e' lo stesso che avete usato per configurare
   `probe-i5.yml`). Se non coincide, l'i5 pubblica su un topic che nessuno
   controlla e il dead-man's switch resta cieco senza dare errori.

   Permessi restrittivi (il file contiene di fatto un topic ntfy, che va
   trattato come un segreto leggero):
   ```
   chmod 600 /etc/mps-heartbeat.conf
   ```

3. **Aggiungere il cron** (consigliato ogni 10 minuti — il cron di un
   sistema Linux vero e' affidabile, a differenza dello schedule di GitHub
   Actions su un repo pubblico, vedi sotto):
   ```
   */10 * * * * /usr/local/bin/heartbeat-publish.sh >> /var/log/mps-heartbeat.log 2>&1
   ```

4. **Verifica manuale prima di fidarsi del cron** — lanciare lo script a
   mano:
   ```
   /usr/local/bin/heartbeat-publish.sh
   ```
   Deve stampare `... heartbeat inviato a ...-heartbeat`.

5. **Verifica lato GitHub** — Actions → "Sonda i5 (dead-man's switch)" →
   Run workflow, con l'input di collaudo a `false`. La cache di ntfy.sh e'
   quasi istantanea (non serve aspettare il prossimo schedule GitHub): se
   il passo 4 e' andato a buon fine, il run risulta verde entro pochi
   secondi. Se il run precedente era rosso (probabile, vedi sotto), questo
   run manda anche la notifica "heartbeat i5 ripreso" — e' la conferma che
   l'installazione ha funzionato end-to-end.

## Cosa succede se non installi subito

Appena la PR viene mergiata, `heartbeat-check.yml` inizia a girare da
solo (schedule gia' attivo nel workflow). Alla prima esecuzione non
trovera' nessun heartbeat (script non ancora installato) e mandera' **una**
notifica ntfy diagnostica ("nessun heartbeat mai ricevuto... controllare
se l'installazione e' stata fatta"), poi restera' silenziosamente rosso
nella pagina Actions (niente spam ripetuto, stessa logica anti-spam di
probe-i5.yml: avvisa solo sulle transizioni). E' il comportamento
corretto e atteso, non un guasto: sparira' da solo al passo 5 sopra.

## Cosa NON fa

- **Non sostituisce `probe-i5.yml`**, che resta attivo: un tunnel
  Cloudflare rotto con i5 acceso e corrente regolare da' un 5xx/timeout
  reale su app/cam, e quello lo becca ancora `probe-i5.yml`. L'heartbeat
  passa da un'altra strada e non lo vedrebbe. I due workflow coprono
  guasti diversi e complementari.
- **Non e' in tempo reale.** Il cron di GitHub Actions su repo pubblico
  non viene onorato agli intervalli nominali (misurato su questo stesso
  repo: intervalli reali 40-155 minuti con un cron nominale di 5 minuti).
  Con la soglia attuale (4 ore) la finestra cieca nel caso peggiore e' di
  circa 6-7 ore, non di pochi minuti — vedi il commento in testa a
  `heartbeat-check.yml` e il README per i dettagli. Non e' un sostituto
  dell'allarme vero via Home Assistant.

## Rollback

Rimuovere la riga di cron e (facoltativo) `/etc/mps-heartbeat.conf`. Il
workflow su GitHub tornera' a segnalare "nessun heartbeat" (rosso fisso,
una sola notifica sulla transizione): innocuo, ma se non lo si vuole piu'
va disattivato anche `heartbeat-check.yml` (Actions → ⋯ → Disable
workflow), altrimenti restera' rosso stabilmente.
