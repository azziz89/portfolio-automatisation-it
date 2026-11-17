# Démo 5 - Tâches administratives : échéances et demandes internes

**Deux automatisations**
1. **Rappel d'échéances** (lun-ven 08h) : liste en 🔴 retard, 🟠 7 jours, 🟡 30 jours (factures, contrats, renouvellements, déclarations).
2. **Demandes internes** : formulaire (congé, matériel, accès informatique) → enregistré dans Google Sheets → notification au responsable.

## Test rapide hors-ligne (sans n8n ni Google)
```bash
cd ~/pack/05-taches-administratives
python3 echeances.py echeances-demo.csv
```
(Les dates d'exemple sont prévues pour novembre 2026 : si vous testez plus tard, modifiez-les.)

## Test n8n
1. Google Sheets : créez un classeur avec **2 onglets**.
   - **Echeances** : importez `echeances-demo.csv`.
   - **Demandes** : en ligne 1, titres exacts : `Numero, DateDemande, Demandeur, Type, Details, DateSouhaitee, Statut`
2. Importez `workflow-administratif.json` dans n8n.
3. Nœuds Google Sheets (« Ajouter dans Demandes », « Lire les echeances ») : choisissez votre connexion Google et collez l'ID du classeur.
4. Nœuds Telegram : remplacez `VOTRE_TOKEN` et `VOTRE_CHAT_ID`.
5. Testez le formulaire (Test URL) puis la branche du bas (*Execute workflow* depuis « Chaque jour ouvre 08h »).

## Résultat attendu (nov. 2026)
- Le formulaire ajoute une ligne `DEM-2026...` et envoie « 📝 Nouvelle demande ... Statut : En attente ».
- Le rappel affiche : contrat climatisation en retard, facture électricité urgente, puis antivirus, déclaration, domaine « à prévoir ». La ligne « Fait » est ignorée.

## Limites honnêtes
- Pas de validation/refus de demande par bouton dans cette version : le responsable change le Statut dans le Sheet.
- Si Google Sheets transforme les dates, mettez la colonne DateEcheance en « Texte brut » et au format AAAA-MM-JJ.
