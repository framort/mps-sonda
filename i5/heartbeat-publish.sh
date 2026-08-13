#!/usr/bin/env bash
# heartbeat-publish.sh — pubblica un heartbeat su ntfy per il dead-man's
# switch della sonda esterna (repo framort/mps-sonda, issue #3).
#
# QUESTO SCRIPT NON E' STATO INSTALLATO DA NESSUN COMMIT DI QUESTO REPO.
# Va copiato e attivato a mano sull'i5 da Francesco, quando autorizza il
# deploy. Vedi docs/INSTALL-HEARTBEAT-I5.md per i passi completi.
#
# Perche' non tocca app.mp-platform.com / cam.mp-platform.com: quei domini
# stanno dietro Cloudflare Access, che risponde 302 dal proprio edge anche
# a i5 spento — e' esattamente il guasto descritto nell'issue #3. Questo
# script esce invece direttamente verso ntfy.sh: prova che l'i5 ha corrente
# e rete, non che il tunnel Cloudflare funzioni (quello lo controlla ancora
# probe-i5.yml, che resta attivo in parallelo).
#
# Il topic va derivato ESATTAMENTE come nel workflow heartbeat-check.yml:
#   <NTFY_TOPIC_BASE>-heartbeat
# dove NTFY_TOPIC_BASE deve essere IDENTICO al valore del secret GitHub
# NTFY_TOPIC del repo framort/mps-sonda. Se non coincide, l'i5 pubblica su
# un topic che nessuno controlla e il dead-man's switch resta cieco in
# silenzio, senza errori visibili.

set -eu

CONFIG_FILE="${MPS_HEARTBEAT_CONFIG:-/etc/mps-heartbeat.conf}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

: "${NTFY_TOPIC_BASE:?Imposta NTFY_TOPIC_BASE in $CONFIG_FILE (stesso valore del secret GitHub NTFY_TOPIC di framort/mps-sonda)}"

TOPIC="${NTFY_TOPIC_BASE}-heartbeat"

if curl -s -m 15 -o /dev/null \
     -H "Priority: min" \
     -H "Tags: heartbeat" \
     -d "beat $(date -Is)" \
     "https://ntfy.sh/${TOPIC}"; then
  echo "$(date -Is) heartbeat inviato a ${TOPIC}"
else
  # Non e' un errore fatale: se questo giro fallisce (rete i5 a singhiozzo),
  # il prossimo tentativo del cron (tra pochi minuti) riprova da solo. La
  # sonda su GitHub reagisce solo se mancano piu' battiti di fila oltre la
  # soglia (ore, non minuti) — vedi heartbeat-check.yml.
  echo "$(date -Is) heartbeat FALLITO verso ${TOPIC} (rete i5 giu'? riprovera' al prossimo giro)" >&2
  exit 1
fi
