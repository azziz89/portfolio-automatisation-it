# Démo 6 - Agents IA : triage de tickets (n8n) + agent à outils (Python)

Deux démonstrations qui montrent la différence entre **automatiser** (règles fixes) et **un agent IA** (comprend le langage naturel, choisit l'action).

## Préparation : clé IA gratuite
1. Allez sur **aistudio.google.com** → *Get API key* (compte Google, sans carte bancaire en principe).
2. Les quotas gratuits et les noms de modèles changent : vérifiez dans AI Studio le modèle disponible (ex. `gemini-2.5-flash`) et modifiez-le si besoin (variable `GEMINI_MODEL` pour Python, URL du nœud pour n8n).
3. **Données fictives uniquement** : sur l'offre gratuite, les données peuvent être utilisées par le fournisseur pour s'améliorer. Ne mettez jamais de données de clients.

---
## A. Agent à outils en Python (`agent-it.py`)  -  le plus impressionnant en démo
L'agent reçoit une phrase, **décide lui-même** quel outil appeler, l'exécute, puis répond.
Outils : `verifier_site`, `diagnostic_machine`, `lire_echeances`, `creer_ticket`.
**Garde-fou** : `creer_ticket` (action qui écrit) demande votre confirmation.

### Test sans clé ni internet (mécanique des outils)
```bash
cd ~/pack/06-agent-ia
python3 agent-it.py --mock
```
Tapez : `echeances`, puis `site`, puis `mon ordinateur est lent`, puis `ticket` (répondez `o` pour confirmer).
Le mode `--mock` est un faux cerveau à mots-clés : il prouve que les outils et la confirmation marchent.

### Test avec la vraie IA
```bash
export GEMINI_API_KEY="votre_cle"
python3 agent-it.py
```
Exemples à poser :
- « Quelles factures ou renouvellements sont en retard ? »
- « Est-ce que https://example.com est en ligne ? »
- « Mon PC est très lent, peux-tu vérifier ? »
- « Crée un ticket priorité haute : l'imprimante du bureau 2 ne marche plus. Demandeur : Rado. »
Vous verrez les lignes `-> outil : ...` : c'est l'agent qui choisit.

---
## B. Triage IA de tickets dans n8n (`workflow-triage-ia.json`)
Formulaire de ticket → **l'IA classe** (catégorie, priorité, résumé, solution à 2-3 étapes, escalade) → enregistrement Google Sheets → notification Telegram (🚨 si escalade).
**Plan B intégré** : si l'IA est en panne ou le quota épuisé, des règles simples prennent le relais (le workflow ne plante pas, la colonne Source l'indique).

### Installation
1. Google Sheets : onglet **Tickets**, ligne 1 : `Numero, Date, Demandeur, Probleme, Categorie, Priorite, Resume, SolutionProposee, Escalade, Source, Statut`
2. Importez le workflow. Nœud **Analyse IA (Gemini)** : remplacez `VOTRE_CLE_GEMINI` (en-tête) et vérifiez le nom du modèle dans l'URL.
3. Nœuds Google Sheets et Telegram : connexion Google, ID du classeur, `VOTRE_TOKEN`, `VOTRE_CHAT_ID`.
4. Test (Test URL du formulaire), ticket fictif : « Tous les PC sont bloqués et un message demande une rançon ».

### Résultat attendu
Ligne ajoutée avec Categorie = Securite, Priorite = Critique, Escalade = Oui, Source = IA, et Telegram :
```
🚨 ESCALADE - Ticket TK-2026...-xxxx [Critique]
Categorie : Securite
Resume : ...
Solution proposee : ...
```
Pour tester le plan B : mettez une fausse clé : Source = « REGLES (IA indisponible) » et Priorite = Critique (le mot « rançon » est détecté).

---
## Comment le présenter (argument de vente)
- « Je ne vends pas un chatbot : je construis des agents **avec garde-fous** (confirmation humaine, plan B sans IA, données non sensibles). »
- Chiffres à mesurer sur vos démos : temps de tri d'un ticket (manuel vs IA), tickets critiques détectés tout de suite.
- Offre : audit gratuit des tâches répétitives → un agent ciblé sur UN processus → abonnement de suivi.

## Limites honnêtes
- Une IA peut se tromper : gardez un humain pour toute action sensible (suppression, paiement, accès).
- Les quotas gratuits sont limités : pour un client réel, prévoyez une clé payante à son nom et une politique de confidentialité claire.
- Je n'ai pas pu tester l'appel réel à l'API ici (pas d'accès à votre clé) : si une erreur API apparaît, envoyez-moi le message complet.
