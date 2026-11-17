# Démo 1 - Supervision et alertes (Telegram)

**Ce que ça fait** : toutes les 5 min, vérifie vos cibles (sites, serveurs avec interface web). Alerte 🚨 après 2 échecs de suite, message ✅ au rétablissement (une seule alerte par panne, pas de spam). Rapport 📊 chaque jour à 07h.

## Installation
1. Importez `workflow-alertes.json`.
2. Dans les nœuds **Alerte Telegram** ET **Rapport Telegram** : remplacez `VOTRE_TOKEN` dans l'URL et `VOTRE_CHAT_ID` dans le corps JSON (mode *Expression*).
3. Dans **Verifier les cibles** : modifiez la liste `TARGETS` (la 2e cible est volontairement fausse pour simuler une panne).
4. Cliquez *Execute workflow* une fois (test manuel : aucune alerte tant que 2 échecs ne sont pas cumulés).
5. Activez le workflow (interrupteur *Active*). Après ~10 min, l'alerte de panne simulée arrive sur Telegram.

## Scénario vidéo (2 min)
1. Montrer le schéma du workflow. 2. Montrer l'alerte 🚨 reçue sur le téléphone. 3. Changer l'URL fictive en URL valide → message ✅ rétabli. 4. Montrer le rapport du matin.

## Limites honnêtes
- Surveille ce qui est joignable depuis la machine où n8n tourne (HTTP/HTTPS). Pas de ping ICMP ni de contrôle de sauvegarde direct : pour cela, un petit script sur le serveur peut appeler un webhook n8n (extension possible).
- Si vous changez de cible/nom, les compteurs repartent à zéro.
