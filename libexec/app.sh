#!/usr/bin/env bash
# app — applications Node.js / Python (Passenger via "Setup Node.js App")
#: o2 node list
#: o2 node create <app-root> <domaine> [--version 20] [--uri /] [--startup server.js] [--mode production]
#: o2 node install <app-root>                   npm install dans l'environnement de l'app
#: o2 node start|stop|restart|destroy <app-root>
#: o2 node set <app-root> [--version N] [--startup f.js] [--mode production|development] [--domain d] [--uri /]
#: o2 node env <app-root> CLE=VALEUR ...         définit les variables d'environnement (remplace l'ensemble)
#: o2 node env <app-root>                        affiche la configuration de l'app (JSON)
#: o2 node exec <app-root> <commande...>         exécute dans l'env de l'app (node/npm dispo), ex. npm run build
#:
#: <app-root> est relatif au home (ex. apps/api). Mêmes commandes avec "o2 python"
#: (--startup passenger_wsgi.py, variable d'entrée "application").
#: Passenger démarre l'app lui-même : l'app doit appeler listen() (le port est ignoré).
. "$O2_ROOT/lib/common.sh"; load_config; need jq

case "${O2_INTERP:-nodejs}" in
  python) interp=python;;
  *) interp=nodejs;;
esac
root() { [ -n "${1:-}" ] || usage 1; printf '%s' "${1#/}"; }
# Convertit --cle valeur ... en options cloudlinux-selector
opts() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --version) o+=(--version "$2"); shift 2;;
      --uri) o+=(--app-uri "${2#/}"); shift 2;;
      --startup) o+=(--startup-file "$2"); shift 2;;
      --mode) o+=(--app-mode "$2"); shift 2;;
      --domain) o+=(--domain "$2"); shift 2;;
      --entry) o+=(--entry-point "$2"); shift 2;;
      *) die "option inconnue : $1";;
    esac
  done
}

cmd="${1:-list}"; shift || true
case "$cmd" in
  list) cls get --interpreter "$interp" | jq '.data';;
  create)
    r="$(root "${1:-}")"; d="${2:-}"; [ -n "$d" ] || usage 1; shift 2
    o=(); opts "$@"
    case " ${o[*]} " in *" --version "*) ;; *) o+=(--version "$([ "$interp" = python ] && echo 3.11 || echo 20)");; esac
    remote_q mkdir -p "$r" >/dev/null
    cls create --interpreter "$interp" --app-root "$r" --domain "$d" "${o[@]}" >/dev/null
    ok "app $interp créée : ~/$r servie sur $d";;
  install) r="$(root "${1:-}")"; cls install-modules --interpreter "$interp" --app-root "$r" >/dev/null && ok "dépendances installées";;
  start|stop|restart|destroy)
    r="$(root "${1:-}")"; cls "$cmd" --interpreter "$interp" --app-root "$r" >/dev/null && ok "$cmd : $r";;
  set) r="$(root "${1:-}")"; shift; o=(); opts "$@"; cls set --interpreter "$interp" --app-root "$r" "${o[@]}" >/dev/null && ok "app mise à jour";;
  env)
    r="$(root "${1:-}")"; shift || true
    if [ $# -eq 0 ]; then
      cls get --interpreter "$interp" | jq --arg r "$r" '[.. | objects | select(.app_root? == $r or has("env_vars"))] | first // "app introuvable"'
    else
      json="$(jq -cn '$ARGS.positional | map(split("=") | {(.[0]): (.[1:] | join("="))}) | add' --args "$@")"
      cls set --interpreter "$interp" --app-root "$r" --env-vars "$json" >/dev/null && ok "variables définies : $(printf '%s\n' "$@" | cut -d= -f1 | paste -sd' ')"
    fi;;
  exec)
    r="$(root "${1:-}")"; shift; [ $# -gt 0 ] || usage 1
    venv="$([ "$interp" = python ] && echo virtualenv || echo nodevenv)"
    # shellcheck disable=SC2016
    remote "v=\$(ls -d ~/$venv/$r/*/ 2>/dev/null | head -1); [ -n \"\$v\" ] || { echo 'o2: environnement introuvable, crée l app d abord' >&2; exit 1; }; source \"\$v/bin/activate\" && cd ~/$r && $(rq "$@")";;
  -h|--help) usage;;
  *) usage 1;;
esac
