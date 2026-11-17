#!/usr/bin/env bash
# Surveillance serveur / réseau (Linux) avec alertes Telegram, sans spam :
# une alerte quand un probleme apparait, un message quand il disparait.
#
# Usage :
#   ./surveillance-serveur.sh --demo      # simulation : problemes fictifs, rien n'est envoye
#   ./surveillance-serveur.sh             # controle normal (a lancer toutes les 5 min par cron)
#   ./surveillance-serveur.sh --rapport   # envoie le resume de l'etat actuel (cron 1x/jour)
set -u

# ================= CONFIGURATION (modifiable) =================
DISK_PATHS=("/")                   # partitions a surveiller
DISK_MAX=85                        # % d'utilisation maximum
RAM_MAX=90                         # % de memoire maximum
LOAD_MAX_PER_CPU="1.5"             # charge moyenne (1 min) maximum par coeur
PING_TARGETS=("1.1.1.1" "8.8.8.8") # internet / equipements a pinguer (ex: "192.168.1.1")
PORTS=("example.com:443")          # services a tester : hote:port
SERVICES=("ssh")                   # services systemd a verifier
BACKUP_DIR=""                      # dossier des sauvegardes (vide = non verifie)
BACKUP_MAX_HOURS=26                # age maximum du fichier le plus recent
# ===============================================================

MODE="check"
case "${1:-}" in --demo) MODE="demo";; --rapport) MODE="rapport";; esac

[ -f "$HOME/.supervision.env" ] && . "$HOME/.supervision.env"   # TG_TOKEN et TG_CHAT_ID peuvent etre ici
TG_TOKEN="${TG_TOKEN:-}"; TG_CHAT_ID="${TG_CHAT_ID:-}"
STATE_DIR="${STATE_DIR:-$HOME/.supervision-state}"
HOST="$(hostname)"

if [ "$MODE" = "demo" ]; then
  # valeurs volontairement "mauvaises" pour provoquer des alertes fictives
  DISK_MAX=1; PING_TARGETS=("192.0.2.1"); PORTS=("127.0.0.1:9"); SERVICES=("service-inexistant-demo")
  STATE_DIR="$(mktemp -d)"
  BACKUP_DIR="$(mktemp -d)"; BACKUP_MAX_HOURS=1; touch -d '3 days ago' "$BACKUP_DIR/sauvegarde-demo.tar.gz"
fi
mkdir -p "$STATE_DIR"

send() {
  if [ "$MODE" = "demo" ] || [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    echo "[SIMULATION - non envoye] $1"; echo
  else
    curl -s -m 10 -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      -d chat_id="$TG_CHAT_ID" --data-urlencode text="$1" >/dev/null || echo "Echec d'envoi Telegram"
  fi
}

SUMMARY=""; PROBLEMS=0
# record <cle> <ok|ko> <message>
record() {
  local key="${1//[^a-zA-Z0-9_.-]/_}" status="$2" msg="$3" prev="ok"
  [ -f "$STATE_DIR/$key" ] && prev="$(cat "$STATE_DIR/$key")"
  if [ "$status" = "ko" ]; then PROBLEMS=$((PROBLEMS+1)); SUMMARY+="🔴 $msg"$'\n'; else SUMMARY+="🟢 $msg"$'\n'; fi
  [ "$MODE" = "rapport" ] && return
  if [ "$status" != "$prev" ]; then
    if [ "$status" = "ko" ]; then send "🚨 [$HOST] PROBLEME : $msg"; else send "✅ [$HOST] RETABLI : $msg"; fi
    echo "$status" > "$STATE_DIR/$key"
  fi
}

# --- Disques ---
for p in "${DISK_PATHS[@]}"; do
  use="$(df -P "$p" 2>/dev/null | awk 'NR==2{gsub("%","",$5);print $5}')"
  if [ -z "$use" ]; then record "disque_$p" ko "Disque $p introuvable"
  elif [ "$use" -ge "$DISK_MAX" ]; then record "disque_$p" ko "Disque $p plein a ${use}% (seuil ${DISK_MAX}%)"
  else record "disque_$p" ok "Disque $p : ${use}%"; fi
done

# --- Memoire ---
ram="$(free | awk '/^Mem:/{printf "%d", $3*100/$2}')"
if [ "$ram" -ge "$RAM_MAX" ]; then record "ram" ko "Memoire a ${ram}% (seuil ${RAM_MAX}%)"; else record "ram" ok "Memoire : ${ram}%"; fi

# --- Charge CPU ---
load="$(awk '{print $1}' /proc/loadavg)"; cpus="$(nproc)"
if awk -v l="$load" -v c="$cpus" -v m="$LOAD_MAX_PER_CPU" 'BEGIN{exit !(l > c*m)}'; then
  record "charge" ko "Charge CPU elevee : $load pour $cpus coeur(s)"
else record "charge" ok "Charge CPU : $load ($cpus coeur(s))"; fi

# --- Ping ---
for t in "${PING_TARGETS[@]}"; do
  if ping -c1 -W2 "$t" >/dev/null 2>&1; then record "ping_$t" ok "Ping $t : repond"
  else record "ping_$t" ko "Ping $t : ne repond pas"; fi
done

# --- Ports / services reseau ---
for hp in "${PORTS[@]}"; do
  h="${hp%%:*}"; p="${hp##*:}"
  if timeout 3 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null; then record "port_$hp" ok "Port $hp : ouvert"
  else record "port_$hp" ko "Port $hp : inaccessible"; fi
done

# --- Services systemd ---
for s in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "$s" 2>/dev/null; then record "svc_$s" ok "Service $s : actif"
  else record "svc_$s" ko "Service $s : arrete ou introuvable"; fi
done

# --- Sauvegardes ---
if [ -n "$BACKUP_DIR" ]; then
  newest="$(find "$BACKUP_DIR" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)"
  if [ -z "$newest" ]; then record "sauvegarde" ko "Sauvegardes : aucun fichier dans $BACKUP_DIR"
  else
    age_h=$(( ( $(date +%s) - ${newest%.*} ) / 3600 ))
    if [ "$age_h" -gt "$BACKUP_MAX_HOURS" ]; then record "sauvegarde" ko "Derniere sauvegarde trop ancienne : ${age_h} h (max ${BACKUP_MAX_HOURS} h)"
    else record "sauvegarde" ok "Derniere sauvegarde : il y a ${age_h} h"; fi
  fi
fi

if [ "$MODE" = "rapport" ] || [ "$MODE" = "demo" ]; then
  if [ "$PROBLEMS" -eq 0 ]; then head="📊 [$HOST] Rapport $(date '+%d/%m/%Y') : tout va bien."
  else head="📊 [$HOST] Rapport $(date '+%d/%m/%Y') : $PROBLEMS probleme(s) a traiter."; fi
  [ "$MODE" = "rapport" ] && send "$head"$'\n\n'"$SUMMARY"
  [ "$MODE" = "demo" ] && { echo "$head"; echo; echo "$SUMMARY"; }
fi
