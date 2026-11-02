#!/usr/bin/env bash
# Helpers partagés par les commandes `o2`. Ce fichier est sourcé, pas exécuté.
set -euo pipefail

O2_CONFIG="${O2_CONFIG:-$HOME/.config/o2switch/config}"
O2_SSH_ALIAS="${O2_SSH_ALIAS:-o2switch}"
UAPI_BIN="${UAPI_BIN:-/usr/local/cpanel/bin/uapi}"
CPAPI2_BIN="${CPAPI2_BIN:-/usr/local/cpanel/bin/cpapi2}"
CLS_BIN="${CLS_BIN:-/usr/bin/cloudlinux-selector}"

die()  { printf 'o2: %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || die "commande manquante en local : $1"; }

load_config() {
  [ -f "$O2_CONFIG" ] || die "pas de configuration ($O2_CONFIG). Lance d'abord : o2 init"
  # shellcheck source=/dev/null
  . "$O2_CONFIG"
  : "${O2_HOST:?O2_HOST manquant dans $O2_CONFIG}"
  : "${O2_USER:?O2_USER manquant dans $O2_CONFIG}"
  O2_API_VIA="${O2_API_VIA:-ssh}"
}

# Quote chaque argument pour qu'il survive au shell distant : rq cmd arg1 "arg 2"
rq() { local out=""; for a in "$@"; do out+="$(printf '%q' "$a") "; done; printf '%s' "${out% }"; }

# Exécute une ligne de commande brute sur l'hébergement.
remote() { ssh "$O2_SSH_ALIAS" -- "$@"; }
# Exécute une commande + arguments, correctement quotés.
remote_q() { ssh "$O2_SSH_ALIAS" -- "$(rq "$@")"; }

json_ok() { printf '%s' "$1" | jq -e . >/dev/null 2>&1; }

# uapi Module fonction cle=valeur ...  → affiche .result.data en JSON, échoue si status != 1
uapi() {
  local out
  if [ "$O2_API_VIA" = "https" ]; then
    out="$(uapi_https "$@")"
  else
    out="$(remote_q "$UAPI_BIN" --output=json "$@" || true)"
  fi
  json_ok "$out" || die "réponse uapi illisible : ${out:-<vide> (SSH ok ? lance : o2 doctor)}"
  if [ "$(printf '%s' "$out" | jq -r '.result.status // 0')" != "1" ]; then
    printf '%s' "$out" | jq -r '.result.errors[]? // "erreur uapi sans message"' | sed 's/^/o2: uapi: /' >&2
    return 1
  fi
  printf '%s\n' "$out" | jq '.result.data'
}

# Même chose en HTTPS avec le jeton d'API (port 2083), sans SSH.
uapi_https() {
  : "${O2_API_TOKEN:?O2_API_TOKEN manquant (nécessaire pour O2_API_VIA=https)}"
  local mod="$1" fn="$2"; shift 2
  local args=()
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  curl -sS -m 60 -G -H "Authorization: cpanel $O2_USER:$O2_API_TOKEN" \
    "https://$O2_HOST:2083/execute/$mod/$fn" "${args[@]}"
}

# cpapi2 (ancienne API, encore utile pour quelques modules) : cpapi2 Module fonction cle=valeur
cpapi2() {
  local out
  out="$(remote_q "$CPAPI2_BIN" --output=json "$@" || true)"
  json_ok "$out" || die "réponse cpapi2 illisible : ${out:-<vide>}"
  printf '%s\n' "$out" | jq '.cpanelresult'
}

# cloudlinux-selector sous-commande options... → JSON, échoue si result != success
cls() {
  local out
  out="$(remote_q "$CLS_BIN" "$@" --json || true)"
  json_ok "$out" || die "réponse cloudlinux-selector illisible : ${out:-<vide>}"
  if [ "$(printf '%s' "$out" | jq -r '.result')" != "success" ]; then
    printf '%s' "$out" | jq -r '.result' | sed 's/^/o2: cloudlinux-selector: /' >&2
    return 1
  fi
  printf '%s\n' "$out"
}

# Ajoute le préfixe cPanel (user_) à un nom de base ou d'utilisateur MySQL s'il manque.
with_prefix() { case "$1" in "${O2_USER}_"*) printf '%s' "$1";; *) printf '%s_%s' "$O2_USER" "$1";; esac; }

# Adresse IP publique de la machine courante.
my_ip() { curl -4 -sS -m 10 https://api.ipify.org || curl -4 -sS -m 10 https://ifconfig.me; }

# Affiche l'aide d'une commande : les lignes "#:" en tête du script.
usage() { sed -n 's/^#: \{0,1\}//p' "$0" >&2; exit "${1:-0}"; }
