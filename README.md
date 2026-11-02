# o2switch-kit

Pilote un hébergement mutualisé **o2switch** (cPanel) depuis le terminal et depuis Claude Code, sans l'interface cPanel.

```
./install.sh      # lien ~/.local/bin/o2 + skill Claude Code ~/.claude/skills/o2switch
o2 init           # hôte, identifiant, jeton d'API, clé SSH, liste blanche, doctor
o2 help
```

Une seule chose à faire dans cPanel, une fois : créer un jeton d'API (Sécurité → Gérer les jetons d'API).
Il sert à mettre ton IP en liste blanche SSH via l'API o2switch ; tout le reste passe par SSH.

| Commande | Rôle |
|---|---|
| `o2 doctor` / `o2 status` | diagnostic, vue d'ensemble |
| `o2 whitelist` | liste blanche pare-feu SSH (API o2switch) |
| `o2 domains` | domaines, sous-domaines, racines |
| `o2 db` | MySQL : création, dump, import, shell |
| `o2 php` | version PHP par domaine |
| `o2 deploy` | rsync d'un projet, piloté par un fichier `.o2switch` |
| `o2 node` / `o2 python` | apps Passenger (Setup Node.js App) via `cloudlinux-selector` |
| `o2 cron`, `o2 ssl`, `o2 email`, `o2 logs` | le reste |
| `o2 api Module fonction k=v` | n'importe quelle fonction UAPI cPanel |

Le skill (`SKILL.md`) contient les recettes par type de projet (statique, PHP, Node, Python) et les pièges.

Sources : [connexion SSH o2switch](https://faq.o2switch.fr/guides/webmastering/connexion-ssh/),
[liste blanche SSH et son API](https://faq.o2switch.fr/cpanel/outils/exception-parefeu/),
[Node.js chez o2switch](https://faq.o2switch.fr/cpanel/logiciels/hebergement-nodejs-multi-version/),
[UAPI cPanel](https://api.docs.cpanel.net/).
