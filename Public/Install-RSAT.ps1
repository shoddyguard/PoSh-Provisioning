<#
.SYNOPSIS
    Installs any RSAT components missing from a system.
.DESCRIPTION
    Checks for the presence of RSAT and installs any missing components
.NOTES
    Module is public as it may occasionally need re-running after a feature upgrade
#>
function Install-RSAT
{
    [CmdletBinding()]
    param ()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $false)
    {
        throw "$($MyInvocation.InvocationName) requires elevation to run."
    }
    # Check to see if we're configured for WSUS only
    $WUSettings = Get-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue
    if ($WUSettings.Property -contains "UseWUServer")
    {
        Write-Verbose "WSUS configured, attempting to disable it temporarily."
        try 
        {
            $CurrentWUSetting = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" | Select-Object -ExpandProperty UseWUServer -ErrorAction Stop
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0 -ErrorAction Stop
            Restart-Service wuauserv -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "WSUS configured and could not change the value.$($_.Exception.Message)"
        }
    }
    try 
    {
        $DisabledFeatures = Get-WindowsCapability -Name RSAT* -Online | Where-Object { $_.State -eq "NotPresent" } -ErrorAction Stop
    }
    catch 
    {
        throw "Failed to get current state of RSAT components.$($_.Exception.Message)"
    }
    Write-Verbose "Currently diabled features: `n$DisabledFeatures"
    Write-Verbose "Attempting to enable disabled features."
    try 
    {
        $DisabledFeatures | Add-WindowsCapability -Online -ErrorAction Stop | Out-Null
    }
    catch 
    {
        throw "Failed to enable RSAT.$($_.Exception.Message)"
    }
    if ($CurrentWUSetting)
    {
        try 
        {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value $CurrentWUSetting -ErrorAction Stop
        }
        catch 
        {
            Write-Error "Failed to set WSUS setting back to $CurrentWUSetting, you will need to set this manually."
        }
        try 
        {
            Restart-Service wuauserv -ErrorAction Stop
        }
        catch 
        {
            Write-Error "Failed to restart the Windows Update service, recommend you reboot your PC."
        }
        
    }
}