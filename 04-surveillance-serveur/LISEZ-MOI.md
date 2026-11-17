# Démo 4 - Surveillance serveur / réseau (Linux, Bash)

**Ce que ça surveille** : disque, mémoire, charge CPU, ping (internet ou équipements), ports/services réseau, services systemd, âge de la dernière sauvegarde.
**Alertes sans spam** : 🚨 quand un problème apparaît, ✅ quand il disparaît (une seule fois chacun). Rapport 📊 quotidien.

## Test immédiat (aucun compte, rien n'est envoyé)
```bash
cd ~/pack/04-surveillance-serveur
chmod +x surveillance-serveur.sh
./surveillance-serveur.sh --demo
```
Résultat : 5 alertes fictives affichées, puis un rapport avec 🔴 et 🟢.

## Test réel
```bash
./surveillance-serveur.sh --rapport     # affiche l'état de VOTRE machine
```
Sans token Telegram, le script affiche `[SIMULATION - non envoye]`. Les 🔴 sur ping/port peuvent venir de votre connexion : c'est un vrai résultat.

## Activer Telegram
Créez le fichier `~/.supervision.env` :
```
TG_TOKEN="votre_token"
TG_CHAT_ID="votre_chat_id"
```

## Automatiser (cron)
`crontab -e` puis ajoutez (adaptez le chemin) :
```
*/5 * * * * /home/VOTRE_NOM/pack/04-surveillance-serveur/surveillance-serveur.sh
0 7 * * * /home/VOTRE_NOM/pack/04-surveillance-serveur/surveillance-serveur.sh --rapport
```

## Personnaliser
Tout est en haut du script : seuils, liste des IP à pinguer (ex. `192.168.1.1`), ports, services, dossier de sauvegarde.

## Limites honnêtes
- Version Linux/Bash. Pour des serveurs Windows, il faudrait une version PowerShell (je peux la faire).
- Le script surveille depuis la machine où il tourne : installez-le sur un serveur ou un PC du réseau du client.
