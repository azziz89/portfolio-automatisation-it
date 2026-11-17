# Démo 3 - Audit et gestion des comptes Microsoft 365

## Fichiers
- `Audit-M365.ps1` : audit en **lecture seule** → `rapport-audit.html` + `comptes.csv` (score, comptes sans MFA, inactifs, désactivés avec licence, admins, licences libres, invités).
- `Nouvel-Employe.ps1` : création de compte + licence + groupes (`-WhatIf` = simulation).
- `Depart-Employe.ps1` : coupe les sessions, désactive, retire licences et groupes.

## Démarrage immédiat, sans compte Microsoft
```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Audit-M365.ps1 -Demo
```
Ouvrez `rapport-audit\rapport-audit.html` → Imprimer → Enregistrer en PDF. Vous avez votre rapport d'exemple (données fictives).

## Avec un vrai tenant de test
1. `Install-Module Microsoft.Graph -Scope CurrentUser`
2. Tenant gratuit : programme Microsoft 365 Developer (éligibilité à vérifier).
3. `.\Audit-M365.ps1 -Client "Mon test"` (connexion en admin, consentement aux permissions de lecture).
4. Arrivée/départ : toujours essayer d'abord avec `-WhatIf`.

## Limites honnêtes
- La date de dernière connexion exige une licence Entra ID P1 minimum ; sinon les comptes apparaissent « inactifs » à tort.
- Ne lancez jamais ces scripts sur le tenant d'un client sans accord écrit. Les scripts d'arrivée/départ modifient des comptes.
- Version 1 : à tester sur un tenant de démo avant tout usage client.
