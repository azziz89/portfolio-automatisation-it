# Démo 2 - Commandes et relances d'impayés

**Ce que ça fait** : un formulaire web (fourni par n8n) enregistre une commande dans Google Sheets, calcule le total, numérote, et notifie le patron sur Telegram. Chaque jour à 08h, les factures impayées depuis 7 jours ou plus sont listées dans un message de relance.

## Installation
1. Dans Google Sheets : créez un classeur, importez `modele-google-sheet.csv`, renommez l'onglet **Commandes** (gardez les titres de colonnes exacts).
2. Copiez l'ID du classeur (la partie de l'URL entre `/d/` et `/edit`).
3. Importez `workflow-commandes.json`.
4. Nœuds **Ajouter dans Google Sheets** et **Lire les commandes** : choisissez/créez l'identifiant Google (*Credential*, connexion OAuth), collez l'ID du classeur.
5. Nœuds Telegram : remplacez `VOTRE_TOKEN` et `VOTRE_CHAT_ID`.
6. Testez : ouvrez le nœud **Formulaire de commande** → *Test URL*, remplissez avec des valeurs fictives. Vérifiez la ligne ajoutée et le message Telegram.
7. Testez la relance : exécutez la branche du bas (*Execute workflow* depuis « Relances chaque jour 08h »). Les lignes d'exemple « Impaye » datées du 01/11 doivent apparaître.

## Limites honnêtes
- Pas de facture PDF dans cette version (étape suivante : modèle Google Docs → PDF). Pas de WhatsApp (API payante) : Telegram/e-mail d'abord.
- Les relances vont au patron, qui contacte le client : plus sûr qu'un envoi automatique en démo.
- Pour passer un statut à « Paye », modifiez la cellule dans Google Sheets.
