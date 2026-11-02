---
name: o2switch
description: Déploie et administre des projets sur un hébergement mutualisé o2switch (cPanel) depuis le terminal, sans jamais ouvrir l'interface cPanel. Utiliser dès qu'il est question d'o2switch, de cPanel, de mettre un site ou une app en ligne sur l'hébergement, d'un sous-domaine, d'une base MySQL, d'un cron, d'un certificat SSL, d'une app Node.js/Python ou d'un e-mail sur cet hébergement.
argument-hint: <ce qu'il faut déployer ou configurer>
---

# o2switch — déployer et piloter cPanel en ligne de commande

Tout passe par la commande `o2` (installée par `install.sh`, source dans `~/.claude/skills/o2switch/`).
Elle parle à l'hébergement en SSH (`ssh o2switch`) et appelle l'API cPanel (`uapi`),
`rsync`, `crontab` et `cloudlinux-selector` côté serveur. `o2 <commande> --help` donne la syntaxe exacte.

Demande : $ARGUMENTS

## 0. Avant toute chose

```bash
o2 doctor          # config, IP en liste blanche, SSH, uapi, outils distants
```

- Pas de config → `o2 init` (interactif, à faire exécuter par l'utilisateur : il saisit hôte, identifiant,
  jeton d'API et, une fois, le mot de passe cPanel). Le jeton se crée dans cPanel → Sécurité → Gérer les jetons d'API :
  c'est la seule action jamais faite dans l'interface.
- « IP absente de la liste blanche » → `o2 whitelist add` (o2switch n'ouvre SSH qu'aux IP déclarées, 5 max, port 22).
- Config dans `~/.config/o2switch/config` (`O2_HOST`, `O2_USER`, `O2_API_TOKEN`). Ne jamais afficher le jeton ni les mots de passe
  dans une réponse ; les écrire dans un `.env` distant ou les transmettre via le `.o2switch`/variables d'app.

## 1. Commandes

| Besoin | Commande |
|---|---|
| Vue d'ensemble | `o2 status` |
| Shell / commande distante | `o2 ssh` · `o2 ssh 'ls public_html'` |
| Domaines | `o2 domains list` · `o2 domains add-sub api.example.com apps/api/public` · `o2 domains add autre.fr` · `o2 domains docroot d chemin` · `o2 domains rm d` |
| MySQL | `o2 db create blog` (affiche `DATABASE_URL`) · `o2 db list` · `o2 db dump blog > blog.sql` · `o2 db import blog f.sql` · `o2 db shell blog` |
| PHP | `o2 php versions` · `o2 php get` · `o2 php set api.example.com 8.3` |
| Déploiement fichiers | `o2 deploy` (lit `.o2switch`) · `o2 deploy -n` (simulation) · `o2 deploy ./dist public_html/site` |
| App Node.js | `o2 node create apps/api api.example.com --version 22 --startup server.js` · `o2 node install apps/api` · `o2 node env apps/api K=V` · `o2 node restart apps/api` · `o2 node exec apps/api npm run build` |
| App Python | mêmes sous-commandes avec `o2 python` (`--startup passenger_wsgi.py`) |
| Cron | `o2 cron list` · `o2 cron add '*/5 * * * *' 'cd ~/apps/x && php bin/console messenger:consume --time-limit=280'` · `o2 cron rm motif` |
| SSL | `o2 ssl status` · `o2 ssl problems` · `o2 ssl run` · `o2 ssl redirect d on` |
| E-mail | `o2 email add contact@example.com` · `o2 email forward a@d b@e` · `o2 email list` |
| Journaux | `o2 logs example.com -f` · `o2 logs php public_html/site` · `o2 logs node apps/api` |
| API brute | `o2 api Module fonction cle=valeur` (UAPI, doc : api.docs.cpanel.net) |
| Liste blanche SSH | `o2 whitelist list|add|rm|clear` |

Les chemins distants sont toujours relatifs au home de l'hébergement (`/home/<identifiant>/`).

## 2. Fichier `.o2switch` à la racine du projet

`o2 deploy init` écrit un modèle. Variables : `REMOTE_DIR` (obligatoire), `LOCAL_DIR`, `BUILD` (commande locale
avant envoi), `EXCLUDE`, `DELETE=1`, `AFTER` (commande distante après envoi, exécutée dans `REMOTE_DIR`), `NODE_APP` /
`PYTHON_APP` (app à redémarrer). Exclusions par défaut : `.git node_modules .env .env.* .o2switch .DS_Store .idea .vscode`.
Le `.env` n'est donc jamais envoyé : le créer une fois côté serveur (`o2 ssh 'cat > ~/apps/x/.env' < .env.production`).

## 3. Recettes par type de projet

**Site statique / Vite / Astro / SPA**
1. `o2 domains add-sub app.example.com public_html/app` (ou garder `public_html` pour le domaine principal).
2. `.o2switch` : `REMOTE_DIR=public_html/app`, `LOCAL_DIR=dist`, `BUILD="npm run build"`, `DELETE=1`.
3. `o2 deploy`. Pour une SPA avec routeur, ajouter un `.htaccess` dans `dist/` qui réécrit vers `index.html`.

**PHP : Symfony / Laravel / WordPress**
1. Sous-domaine avec racine sur `public/` : `o2 domains add-sub api.example.com apps/api/public`.
2. `o2 php set api.example.com 8.3` · `o2 db create api` → mettre les accès dans le `.env` distant.
3. `.o2switch` : `REMOTE_DIR=apps/api`, `EXCLUDE="vendor var/cache var/log tests"`,
   `AFTER="composer install --no-dev --optimize-autoloader && php bin/console cache:clear && php bin/console doctrine:migrations:migrate -n"`.
   `composer` est installé nativement ; `php` suit la version choisie par `o2 php set`.
4. Workers / files d'attente : un cron (`o2 cron add`) avec `--time-limit`, pas de processus résident.

**Node.js (Express, Fastify, Next.js en serveur custom, etc.)**
1. L'app est lancée par Passenger : elle doit exporter/appeler `listen()` (port ignoré, Passenger impose un socket Unix).
   Avec plusieurs `listen`, utiliser `app.listen('passenger')` si `typeof PhusionPassenger !== 'undefined'`.
   Une app qui n'écoute pas (bot, worker) n'est pas faite pour Passenger : la lancer en cron.
2. Créer d'abord le sous-domaine (`o2 domains add-sub api.example.com public_html/api`), puis
   `o2 node create apps/api api.example.com --version 22 --startup server.js --mode production`
   (`app-root` hors de `public_html` ; Passenger relie le domaine à l'app via un `.htaccess` dans la racine du domaine).
3. `.o2switch` : `REMOTE_DIR=apps/api`, `BUILD="npm run build"` si nécessaire, `NODE_APP=apps/api`,
   `AFTER` vide ; puis `o2 node install apps/api` après le premier déploiement (et après tout changement de `package.json`).
4. Variables : `o2 node env apps/api NODE_ENV=production DATABASE_URL=...` (remplace l'ensemble des variables à chaque appel).
5. Pas de compilateur (`gcc`, `node-gyp`) : éviter les dépendances natives, ou demander au support.
6. Débogage : `o2 logs node apps/api`.

**Python (Flask, Django, FastAPI via WSGI)**
`o2 python create apps/py api.example.com --version 3.11 --startup passenger_wsgi.py --entry application`,
puis `o2 python exec apps/py pip install -r requirements.txt`.

## 4. Pièges connus

- DNS : un domaine ajouté n'est joignable et n'a de certificat que lorsque ses enregistrements pointent vers l'hébergement
  (`o2 ssl problems` dit pourquoi AutoSSL attend). Les sous-domaines d'un domaine déjà chez o2switch sont immédiats.
- Préfixe MySQL : bases et utilisateurs sont préfixés `<identifiant>_` ; `o2 db` l'ajoute tout seul. Hôte : `localhost`.
- Pas de root, pas de `apt`, pas de Docker, pas de démon résident : tout ce qui tourne en continu passe par Passenger ou un cron.
- `o2 cron` manipule la crontab brute ; cPanel n'expose pas de UAPI Cron.
- Les commandes lisent/écrivent uniquement ce que l'utilisateur demande ; `o2 domains rm` et `o2 db rm` sont destructifs :
  les lancer seulement sur demande explicite.
