<#
.SYNOPSIS  Cree un compte Microsoft 365 (arrivee d'un employe).
.EXAMPLE   .\Nouvel-Employe.ps1 -Prenom "Rado" -Nom "Rakoto" -Domaine "exemple.mg" -Service "Compta" -Licence "O365_BUSINESS_PREMIUM" -Groupes "Comptabilite" -WhatIf
           (-WhatIf = simulation, rien n'est cree)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][string]$Prenom,
  [Parameter(Mandatory)][string]$Nom,
  [Parameter(Mandatory)][string]$Domaine,
  [string]$Service, [string]$Poste, [string]$Licence,
  [string[]]$Groupes = @(),
  [string]$Pays = 'MG'
)
$ErrorActionPreference = 'Stop'
function Remove-Accents([string]$t){
  $n = $t.Normalize([Text.NormalizationForm]::FormD)
  (($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' }) -join '') -replace '[^a-zA-Z0-9\.\-]',''
}
function New-Pwd {
  $pools = @('ABCDEFGHJKLMNPQRSTUVWXYZ','abcdefghijkmnpqrstuvwxyz','23456789','!@#$%?')
  $chars = foreach($p in $pools){ $p[(Get-Random -Maximum $p.Length)] }
  $all = ($pools -join '')
  $chars += 1..12 | ForEach-Object { $all[(Get-Random -Maximum $all.Length)] }
  -join ($chars | Sort-Object { Get-Random })
}
$upn = ("{0}.{1}@{2}" -f (Remove-Accents $Prenom),(Remove-Accents $Nom),$Domaine).ToLower()
$pwd = New-Pwd
if ($PSCmdlet.ShouldProcess($upn,"Creer le compte")) {
  Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.ReadWrite.All" -NoWelcome
  $u = New-MgUser -BodyParameter @{
    accountEnabled=$true; displayName="$Prenom $Nom"; mailNickname=($upn.Split('@')[0])
    userPrincipalName=$upn; givenName=$Prenom; surname=$Nom; department=$Service; jobTitle=$Poste; usageLocation=$Pays
    passwordProfile=@{ forceChangePasswordNextSignIn=$true; password=$pwd }
  }
  if ($Licence) {
    $sku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $Licence }
    if ($sku) { Set-MgUserLicense -UserId $u.Id -AddLicenses @(@{ SkuId=$sku.SkuId }) -RemoveLicenses @() | Out-Null }
    else { Write-Warning "Licence '$Licence' introuvable." }
  }
  foreach ($g in $Groupes) {
    $grp = Get-MgGroup -Filter "displayName eq '$g'"
    if ($grp) { New-MgGroupMember -GroupId $grp.Id -DirectoryObjectId $u.Id } else { Write-Warning "Groupe '$g' introuvable." }
  }
  Write-Host "Compte cree : $upn" -ForegroundColor Green
  Write-Host "Mot de passe temporaire : $pwd (a changer a la 1ere connexion)" -ForegroundColor Yellow
  "{0};ARRIVEE;{1}" -f (Get-Date -Format s),$upn | Add-Content -Path ".\journal-comptes.log"
}
