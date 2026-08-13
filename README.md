# mps-sonda — heartbeat esterno dell'i5 (solo workflow, nessun dato sensibile)

Due workflow, due guasti diversi, entrambi via ntfy (topic nel secret
`NTFY_TOPIC`, nessun altro segreto in chiaro nel repo):

## `probe-i5.yml` — controllo esterno di app/cam

Interroga `app.mp-platform.com` e `cam.mp-platform.com` dall'esterno ogni
5 minuti (nominali). Vede: tunnel Cloudflare rotto con i5 acceso e
corrente regolare (5xx/timeout reale).

**Limite noto (issue #3):** quei domini stanno dietro Cloudflare Access,
che risponde `302` dal proprio edge **senza mai contattare l'i5** — anche
a casa senza corrente. Verificato col blackout del 12/08: con la casa
senza corrente da 47 secondi, la sonda ha stampato OK. Non e' un bug
sistemabile con un retry: questo controllo **non puo' fisicamente vedere**
un guasto totale (i5/corrente/tunnel tutti giu' insieme).

## `heartbeat-check.yml` — dead-man's switch

Non chiede "sei vivo?" a chi risponde sempre di si'. Aspetta un segnale
che solo l'i5 puo' produrre: un heartbeat pubblicato su ntfy.sh (topic
`<NTFY_TOPIC>-heartbeat`, derivato dallo stesso secret — nessun secret
nuovo) direttamente dall'i5, **senza passare dal tunnel Cloudflare ne' dai
domini app/cam**. Se l'heartbeat manca da troppo tempo, avvisa.

Lo script che l'i5 deve eseguire e' in `i5/heartbeat-publish.sh` — **non
installato da nessun commit di questo repo**. Vedi
`docs/INSTALL-HEARTBEAT-I5.md` per i passi, da autorizzare ed eseguire a
mano da Francesco sull'i5.

I due workflow sono complementari: quello che l'uno non vede (guasto
totale per `probe-i5.yml`, guasto del solo tunnel per `heartbeat-check.yml`)
lo vede l'altro.

## La verita' sui tempi: NON e' un monitor in tempo reale

Il cron di GitHub Actions su repo pubblico **non viene onorato agli
intervalli nominali**. Misurato su questo repo: con un cron nominale di 5
minuti, gli intervalli reali fra un run e l'altro sono stati **40-155
minuti**. La finestra cieca di `probe-i5.yml` e' quindi di circa un'ora
nella pratica, non di 5 minuti.

`heartbeat-check.yml` usa una soglia di **4 ore** (non minuti) proprio per
non confondere il ritardo di schedulazione di GitHub con un guasto vero:
una soglia vicina al ritardo massimo osservato (155 min) genererebbe falsi
allarmi ogni volta che uno schedule slitta, senza alcun guasto reale.
Con questa soglia, la finestra cieca nel caso peggiore osservato e' di
**circa 6-7 ore** (soglia 4h + fino a ~155 min di ritardo di
schedulazione). Nella pratica sara' quasi sempre piu' veloce (i ritardi
di 150+ minuti sono la coda della distribuzione, non la norma), ma va
trattato onestamente come un rilevatore "ce ne accorgiamo entro qualche
ora", non un allarme in tempo reale — quello lo fa il sistema antifurto
vero via Home Assistant.

## Collaudo (deve poter diventare rossa a comando)

`heartbeat-check.yml` ha un input manuale (Actions → Run workflow →
`simula_heartbeat_mancante`) che forza il ramo "heartbeat mancante" senza
aspettare ore: il run risulta rosso per davvero e manda un alert ntfy reale
marcato `[COLLAUDO]`, cosi' si verifica anche la consegna sul telefono. Il
run successivo (schedulato, o manuale con l'input a `false`) vede lo stato
precedente come "failure" e, se l'heartbeat reale e' a posto, manda anche
l'alert di ripristino — un solo collaudo esercita entrambi i rami
(down + up). Vedi il commento in testa a `heartbeat-check.yml`.

## Perche' repo pubblico

Sui repo pubblici le Actions non consumano i 2000 min/mese del piano: una
sonda ogni 5 min in un repo privato avrebbe bruciato la quota in una
settimana, bloccando anche altre build (presa di Francesco, 17/07). Nessun
dato sensibile nel repo: solo workflow e nomi di endpoint pubblici, i
segreti (topic ntfy) stanno nei secret di Actions.
