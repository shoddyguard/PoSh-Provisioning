[CmdletBinding()]
param()

# Get the folder wot contains everything.
$PublicCmdlets =@()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

$ErrorActionPreference = 'Stop'

# Import our modules and export public functions
"$PSScriptRoot\Private\" |
    Resolve-Path |
    Get-ChildItem -Filter *.ps1 -Recurse |
    ForEach-Object {
      . $_.FullName
    }

"$PSScriptRoot\Public\" |
    Resolve-Path |
    Get-ChildItem -Filter *.ps1 -Recurse |
    ForEach-Object {
      . $_.FullName
      Export-ModuleMember -Function $_.BaseName
      $PublicCmdlets += Get-Help $_.BaseName
    }

Write-Host "The following cmldets are now available for use:" -ForegroundColor White
$PublicCmdlets | ForEach-Object { Write-Host "    $($_.Name) " -ForegroundColor Yellow -NoNewline; Write-Host "|  $($_.Synopsis)" -ForegroundColor White} 

if (($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $false)
{
    Write-Warning "Some cmdlets require elevation, you may need to restart PowerShell as an Administrator to be able to use this module effectively."
}