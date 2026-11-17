# Portfolio : automatisation IT et agents IA

Démonstrations construites avec des **données fictives** (aucune donnée réelle de client ou d'employeur).

## État des démos

| Démo | Description | État |
|---|---|---|
| 03 Audit Microsoft 365 | Rapport de sécurité avec PowerShell | ✅ testé (mode démo) |
| 04 Surveillance serveur | Disque, CPU, ping, services, sauvegardes, alertes | ✅ testé (mode simulation) |
| 05 Échéances (Python) | Rappel des factures et renouvellements | ✅ testé |
| 06 Agent IA (Python) | Agent à outils avec confirmation humaine | ✅ testé en mode `--mock` |
| 01, 02, 05 et 06 (versions n8n) | Alertes, commandes, demandes, triage IA | 🔧 en cours de test |
| 03 Arrivée et départ d'un employé | Scripts Microsoft Graph | 🔧 non testés sur un tenant |

## Lancer un test (Linux, sans compte)
```bash
bash 04-surveillance-serveur/surveillance-serveur.sh --demo
python3 05-taches-administratives/echeances.py 05-taches-administratives/echeances-demo.csv
python3 06-agent-ia/agent-it.py --mock
pwsh 03-audit-m365/Audit-M365.ps1 -Demo
```

## Contact
Odda Azzy LEMAVERANA ESLA : VOTRE_EMAIL_PRO
