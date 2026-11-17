<#
.SYNOPSIS  Depart d'un employe : coupe les sessions, desactive le compte, retire licences et groupes.
.EXAMPLE   .\Depart-Employe.ps1 -UPN "rado.rakoto@exemple.mg" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$UPN)
$ErrorActionPreference = 'Stop'
if ($PSCmdlet.ShouldProcess($UPN,"Desactiver, retirer licences et groupes")) {
  Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.ReadWrite.All" -NoWelcome
  $u = Get-MgUser -UserId $UPN -Property "id,displayName,assignedLicenses"
  Revoke-MgUserSignInSession -UserId $u.Id | Out-Null
  Update-MgUser -UserId $u.Id -AccountEnabled:$false
  $ids = @($u.AssignedLicenses | ForEach-Object { $_.SkuId })
  if ($ids.Count) { Set-MgUserLicense -UserId $u.Id -AddLicenses @() -RemoveLicenses $ids | Out-Null }
  foreach ($m in (Get-MgUserMemberOf -UserId $u.Id -All)) {
    if ($m.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group') {
      try { Remove-MgGroupMemberByRef -GroupId $m.Id -DirectoryObjectId $u.Id }
      catch { Write-Warning "Groupe non modifiable : $($m.AdditionalProperties.displayName)" }
    }
  }
  Write-Host "Depart traite : $UPN" -ForegroundColor Green
  "{0};DEPART;{1}" -f (Get-Date -Format s),$UPN | Add-Content -Path ".\journal-comptes.log"
}
