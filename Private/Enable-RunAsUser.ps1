<#
.SYNOPSIS
    Adds "Run as different user" to the Start menu
.DESCRIPTION
    Adds "Run as different user" to the Start menu
.NOTES
    Moved into cmdlet just to keep the clutter in the main script down
#>
function Enable-RunAsUser
{
    [CmdletBinding()]
    param ()

    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    $RegProp = "ShowRunAsDifferentUserInStart"
    $RegVal = 1
    if (!(Test-Path $RegPath))
    {
        Write-Verbose "Registry path does not exist, creating from scratch"
        try
        {
            New-Item $RegPath -ErrorAction Stop | Out-Null
            New-ItemProperty -Path $RegPath -Name $RegProp -Value $RegVal -PropertyType DWord -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "Failed to create registry item.`n$($_.Exception.Message)"
        }
    }
    else 
    {
        if ((Get-ItemProperty $RegPath -Name $RegProp -ErrorAction SilentlyContinue))
        {   
            Write-Verbose "Registry property found! Ensuring it's enabled"
            try
            {
                Set-ItemProperty -Path $RegPath -Name $RegProp -Value $RegVal
            }
            catch
            {
                throw "Failed to set registry property.`n$($_.Exception.Message)"
            }
        }
        else 
        {
            Write-Verbose "Registry path exists, but property does not, attempting to create"
            try
            {
                New-ItemProperty -Path $RegPath -Name $RegProp -Value $RegVal -PropertyType DWord -ErrorAction Stop | Out-Null
            }
            catch
            {
                throw "Failed to create registry property.`n$($_.Exception.Message)"
            }
            
        }
    }
}