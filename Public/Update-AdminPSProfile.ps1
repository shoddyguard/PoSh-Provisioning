<#
.SYNOPSIS
    Copies a PowerShell profile to the specified account
.DESCRIPTION
    This is useful for when the user has a normal unprivilidged account and an account that has domain admin that will therefore have a different profile.
.EXAMPLE
    PS C:\> Update-AdminPSProfile -Username my.admin -Domain FOO-BAR -SourcePath C:\VSCode\profile_template.ps1
    This would copy the profile at C:\VSCode\profile_template.ps1 to C:\Users\my.admin\Documents\WindowsPowershell\Microsoft.PowerShell_profile.ps1
.NOTES
    Username should be supplied without any doamin (eg Joe.Bloggs not Joe.Bloggs@my-corp.com)
#>
function Update-AdminPSProfile
{
    [CmdletBinding()]
    param 
    (
        # The username of the administrator account
        [Parameter(Mandatory = $true)]
        [string]
        $Username,

        # The domain name
        [Parameter(Mandatory = $true)]
        [string]
        $Domain,

        # The path to where the profile you want to copy lives
        [Parameter(Mandatory = $true)]
        [string]
        $SourcePath,

        # The credentials for the admin user
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $false)
    {
        throw "$($MyInvocation.InvocationName) requires elevation to run."
    }
    if (!(Test-Path $SourcePath))
    {
        Throw "Failed to find $SourcePath"
    }
    # Check the admin account has signed in before, if not create them a profile by launching an app as their account.
    if (!(Test-Path "$env:SystemDrive\Users\$Username"))
    {
        if (!$Credential)
        {
            $Credential = Get-Credential -Message "Please enter the password for $username" -UserName "$domain\$username"
        }
        try
        {
            Start-Process powershell -ErrorAction Stop -Credential $Credential -ArgumentList "exit"
        }
        catch
        {
            throw "Failed to login as supplied user, are you sure the credentials are correct and you're on the domain?"
        }
    }
    $guestimatedpath = "$env:SystemDrive\Users\$Username\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    $PotentialParent = Split-Path $guestimatedpath
    if (!(Test-Path $PotentialParent))
    {
        try
        {
            New-Item $PotentialParent -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "Failed to create parent directory: $PotentialParent.`n$($_.Exception.Message)"
        }
    }
    try
    {
        Copy-Item $SourcePath -Destination $GuestimatedPath -Force -ErrorAction Stop | Out-Null
        #Start-Process powershell -WorkingDirectory $tempath -Credential $Credential -ArgumentList "Copy-Item $file -Path $GuestimatedPath -Force -ErrorAction Stop" -Wait
    }
    catch
    {
        throw "Failed to copy profile.`n$($_.Exception.Message)"
    }
}