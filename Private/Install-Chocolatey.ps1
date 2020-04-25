<#
.SYNOPSIS
    Installs Chocolatey.
.DESCRIPTION
    Installs Chocolatey
.EXAMPLE
    Install-Chocolatey
.NOTES
    Very basic
#>
function Install-Chocolatey
{
    [CmdletBinding()]
    param 
    ()
    Write-Output "Installing Chocolatey"
    if (([Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls12')-ne $true)
    {
        throw "TLS 1.2 either not supported or cannot be enabled on your system"
    }
    if (([System.Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12))-ne $true)
    {
        try 
        {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
        catch 
        {
            throw "Failed to set TLS 1.2.`n$($_.Exception.Message)"
        }
    }
    if (([System.Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12))-ne $true)
    {
        throw "Tried to set TLS 1.2 but it still isn't active."
    }
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}
