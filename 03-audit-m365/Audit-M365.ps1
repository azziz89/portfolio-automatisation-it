<#
.SYNOPSIS
  Audit de securite Microsoft 365 / Entra ID (LECTURE SEULE) avec rapport HTML + CSV.
.EXAMPLE
  .\Audit-M365.ps1 -Demo                       # donnees FICTIVES, aucun compte requis
  .\Audit-M365.ps1 -Client "Mon client"        # audit reel (connexion Microsoft Graph)
#>
[CmdletBinding()]
param(
  [switch]$Demo,
  [int]$InactiveDays = 90,
  [string]$Client = "Client fictif SA",
  [string]$OutDir = (Join-Path (Get-Location) "rapport-audit")
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$now = Get-Date

if ($Demo) {
  Write-Host "MODE DEMO : donnees fictives" -ForegroundColor Yellow
  function U($n,$en,$days,$mfa,$lic,$type,$adm){
    [pscustomobject]@{ Nom=$n; UPN=(($n -replace ' ','.').ToLower()+"@exemple.mg"); Actif=$en
      DerniereConnexion=$(if($days -ge 0){$now.AddDays(-$days)}else{$null}); MFA=$mfa; Licences=$lic; Type=$type; AdminGlobal=$adm }
  }
  $users = @(
    (U "Rado Rakoto"      $true  2   $true  "SPE_E3" "Member" $true),
    (U "Hery Andria"      $true  1   $true  "SPE_E3" "Member" $true),
    (U "Naivo Razafy"     $true  5   $false "O365_BUSINESS_PREMIUM" "Member" $false),
    (U "Lanto Rabe"       $true  140 $false "O365_BUSINESS_PREMIUM" "Member" $false),
    (U "Faly Randria"     $false 200 $false "O365_BUSINESS_PREMIUM" "Member" $false),
    (U "Tiana Rasoa"      $true  -1  $false "O365_BUSINESS_PREMIUM" "Member" $false),
    (U "Mialy Ravelo"     $true  3   $true  "O365_BUSINESS_PREMIUM" "Member" $false),
    (U "Consultant Externe" $true 60 $false "" "Guest" $false)
  )
  $skus = @(
    [pscustomobject]@{ Licence="SPE_E3"; Total=5; Utilisees=2; Libres=3 },
    [pscustomobject]@{ Licence="O365_BUSINESS_PREMIUM"; Total=10; Utilisees=5; Libres=5 }
  )
}
else {
  if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host "Installez d'abord : Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Red; exit 1
  }
  Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All","UserAuthenticationMethod.Read.All","Directory.Read.All" -NoWelcome
  $skuRaw = Get-MgSubscribedSku
  $skuName = @{}; foreach($s in $skuRaw){ $skuName[[string]$s.SkuId] = $s.SkuPartNumber }
  $skus = $skuRaw | ForEach-Object {
    $total = $_.PrepaidUnits.Enabled
    [pscustomobject]@{ Licence=$_.SkuPartNumber; Total=$total; Utilisees=$_.ConsumedUnits; Libres=($total - $_.ConsumedUnits) }
  }
  $adminIds = @()
  try {
    $role = Get-MgDirectoryRole -All | Where-Object { $_.DisplayName -eq 'Global Administrator' }
    if ($role) { $adminIds = @(Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All | ForEach-Object { $_.Id }) }
  } catch { Write-Warning "Roles admin non lisibles : $($_.Exception.Message)" }

  $raw = Get-MgUser -All -Property "id,displayName,userPrincipalName,accountEnabled,userType,assignedLicenses,signInActivity"
  $i = 0
  $users = foreach ($u in $raw) {
    $i++; Write-Progress -Activity "Analyse des comptes" -Status "$i / $($raw.Count)" -PercentComplete (100*$i/$raw.Count)
    $mfa = $false
    try {
      $m = Get-MgUserAuthenticationMethod -UserId $u.Id
      $mfa = (@($m | Where-Object { $_.AdditionalProperties.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' })).Count -gt 0
    } catch { }
    $lic = ($u.AssignedLicenses | ForEach-Object { $skuName[[string]$_.SkuId] }) -join ", "
    [pscustomobject]@{
      Nom=$u.DisplayName; UPN=$u.UserPrincipalName; Actif=[bool]$u.AccountEnabled
      DerniereConnexion=$u.SignInActivity.LastSignInDateTime; MFA=$mfa; Licences=$lic
      Type=$u.UserType; AdminGlobal=($adminIds -contains $u.Id)
    }
  }
}

# ---------- Analyse ----------
$limit = $now.AddDays(-$InactiveDays)
$inactifs   = @($users | Where-Object { $_.Actif -and $_.Type -eq 'Member' -and ((-not $_.DerniereConnexion) -or $_.DerniereConnexion -lt $limit) })
$desactLic  = @($users | Where-Object { (-not $_.Actif) -and $_.Licences })
$sansMfa    = @($users | Where-Object { $_.Actif -and $_.Type -eq 'Member' -and (-not $_.MFA) })
$invites    = @($users | Where-Object { $_.Type -eq 'Guest' })
$admins     = @($users | Where-Object { $_.AdminGlobal })
$licLibres  = @($skus | Where-Object { $_.Libres -gt 0 })

$score = 100
if ($sansMfa.Count)   { $score -= [math]::Min(40, 8*$sansMfa.Count) }
if ($inactifs.Count)  { $score -= [math]::Min(20, 5*$inactifs.Count) }
if ($desactLic.Count) { $score -= [math]::Min(15, 5*$desactLic.Count) }
if ($admins.Count -gt 4 -or $admins.Count -lt 2) { $score -= 10 }
if ($score -lt 0) { $score = 0 }

function Section($titre,$prio,$items,$conseil){
  $color = switch($prio){ 'HAUTE'{'#c0392b'} 'MOYENNE'{'#e67e22'} default{'#2980b9'} }
  $tbl = if ($items.Count) { ($items | ConvertTo-Html -Fragment) -join "`n" } else { "<p>Rien a signaler.</p>" }
  "<h2>$titre <span style='background:$color;color:#fff;padding:2px 8px;border-radius:4px;font-size:12px'>PRIORITE $prio</span></h2><p><b>$($items.Count)</b> element(s). <i>$conseil</i></p>$tbl"
}
$body = @()
$body += Section "1. Comptes actifs SANS MFA" "HAUTE" ($sansMfa | Select-Object Nom,UPN) "Activer le MFA / acces conditionnel pour tous les utilisateurs."
$body += Section "2. Comptes desactives avec licence" "MOYENNE" ($desactLic | Select-Object Nom,UPN,Licences) "Retirer les licences : economie immediate."
$body += Section "3. Comptes inactifs depuis plus de $InactiveDays jours" "MOYENNE" ($inactifs | Select-Object Nom,UPN,DerniereConnexion) "Verifier puis desactiver les comptes d'anciens employes."
$body += Section "4. Administrateurs globaux" "HAUTE" ($admins | Select-Object Nom,UPN) "Idealement 2 a 4 comptes admin, tous proteges par MFA."
$body += Section "5. Licences non utilisees" "MOYENNE" $licLibres "Reduire le nombre de licences achetees."
$body += Section "6. Comptes invites (externes)" "BASSE" ($invites | Select-Object Nom,UPN,DerniereConnexion) "Revoir regulierement les acces externes."

$html = @"
<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>Audit M365 - $Client</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;max-width:900px;margin:30px auto;color:#222}
table{border-collapse:collapse;width:100%;margin-bottom:10px}th,td{border:1px solid #ccc;padding:5px 8px;font-size:13px;text-align:left}th{background:#f0f0f0}
.score{font-size:42px;font-weight:bold}</style></head><body>
<h1>Audit de securite Microsoft 365</h1>
<p>Client : <b>$Client</b> &nbsp;|&nbsp; Date : $($now.ToString('dd/MM/yyyy')) $(if($Demo){'&nbsp;|&nbsp; <b>DONNEES FICTIVES (DEMO)</b>'})</p>
<p>Score de securite : <span class="score">$score / 100</span> &nbsp; ($($users.Count) comptes analyses)</p>
$($body -join "`n")
<hr><p style="font-size:12px;color:#666">Audit en lecture seule realise avec PowerShell et Microsoft Graph.</p></body></html>
"@
$htmlPath = Join-Path $OutDir "rapport-audit.html"
$html | Out-File -FilePath $htmlPath -Encoding utf8
$users | Export-Csv -Path (Join-Path $OutDir "comptes.csv") -NoTypeInformation -Encoding UTF8
Write-Host "Termine. Score : $score/100" -ForegroundColor Green
Write-Host "Rapport : $htmlPath  (ouvrez-le puis Imprimer > Enregistrer en PDF)"
