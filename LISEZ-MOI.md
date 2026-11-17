# Pack Portfolio - 6 démos (budget zéro)

| # | Dossier | Outil | Besoin |
|---|---------|-------|--------|
| 1 | 01-alertes-supervision | n8n + Telegram | n8n, un bot Telegram (gratuit) |
| 2 | 02-commandes-relances | n8n + Google Sheets + Telegram | + compte Google (gratuit) |
| 3 | 03-audit-m365 | PowerShell + Microsoft Graph | PowerShell ; **mode -Demo sans compte** |
| 4 | 04-surveillance-serveur | Bash (Linux) + Telegram | aucun compte pour tester (`--demo`) |
| 5 | 05-taches-administratives | n8n + Google Sheets (ou Python hors-ligne) | `python3 echeances.py` sans compte |
| 6 | 06-agent-ia | Agent IA (Python) + triage IA (n8n) | clé Gemini gratuite ; `--mock` sans clé |

## Préparation commune (15 min, une seule fois)

**n8n gratuit sur votre PC** : installez Node.js (version LTS), puis dans un terminal :
`npx n8n` → ouvrez http://localhost:5678. (Les workflows planifiés ne tournent que PC allumé et workflow *Active*.)

**Bot Telegram** :
1. Dans Telegram, ouvrez **@BotFather** → `/newbot` → notez le **TOKEN**.
2. Écrivez « bonjour » à votre nouveau bot.
3. Ouvrez dans le navigateur `https://api.telegram.org/botVOTRE_TOKEN/getUpdates` et notez le nombre après `"chat":{"id":` : c'est votre **CHAT_ID**.

**Importer un workflow** : n8n → *Create workflow* → menu ⋯ → *Import from file*.

## Règle d'or
N'utilisez que des **données fictives** dans vos démos (jamais de données d'un ancien employeur).
Si une erreur apparaît : envoyez-moi une capture **de l'erreur ET du nœud concerné**.
