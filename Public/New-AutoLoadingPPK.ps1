<#
.SYNOPSIS
    Creates a PuTTY keypair that is autoloaded on login
.EXAMPLE
    PS C:\> New-AutoLoadingPPK -KeyName PuppetMaster -KeyPath C:\Keys
    Would create the key C:\Keys\PuppetMaster.ppk and add it to the autoloader list.
.OUTPUTS
    Will create PPKLoader.txt in %APPDATA%\ShoddyGuard\Provisioner and a shortcut to pageant in the Start menus 'startup' folder
.NOTES
    It would be nice if PuTTY had some way of generating these keys via a script, even if it was just via some salt...anyways this will do for now.
    Todo:
        Some logic in the PPK loader import-export to avoid duplicate keys
        Originally I was writing to a text file and using a scheduled task to launch pageant, now that I'm not doing that it might be easier to simply pull the info from the existing shortcut?
#>
function New-AutoLoadingPPK
{
    [CmdletBinding()]
    param 
    (
        # The path to where the key *should* end up. Doesn't really do much but helps with automation
        [Parameter(Mandatory = $true)]
        [string]
        $KeyName,

        # The path to store the key
        [Parameter(Mandatory = $true)]
        [string]
        $KeyPath
    )
    $PPKLoader = "$env:SGProvisionFolder\PPKLoader.txt"
    if (Test-Path $PPKLoader)
    {
        $CurrentPPKList = @(Get-Content $PPKLoader -ErrorAction SilentlyContinue) # soft fail
    }
    $KeyName = $KeyName -replace ".ppk", "" # just in case it's been accidentally supplied
    $KeyPath = "$KeyPath\$KeyName.ppk"
    if (Test-Path $KeyPath)
    {
        Write-Warning "Key already exists at $Keypath, it will be skipped"
        continue # this gets us into a state where the key won't get autoloaded by pageant. We should put some logic in here.
    }
    Write-Host "Putty will now be launched to generate your keypair, if you save your private key as $KeyPath the script will be able to automatically continue."
    Write-Warning "Remember to copy the public key!"
    Read-Host "Press enter to continue..."
    try 
    {
        Start-Process puttygen -wait -ErrorAction Stop
    }
    catch 
    {
        throw "Failed to start PuTTYGen or it exited with a non-zero code:`n$($_.Exception.Message)"
    }
    $KeyFound = Test-Path $KeyPath
    while ($KeyFound -eq $false) 
    {
        Write-Host "Key not found in location $KeyPath" -ForegroundColor Red
        $KeyPath = Read-Host "Please enter the complete path to the key"
        $KeyFound = Test-Path $KeyPath
    }
    if ($CurrentPPKList)
    {
        Write-Verbose "Looks like there's already some auto-loading keys, adding $KeyPath to the list."
        $CurrentPPKList += $KeyPath
        try 
        {
            Set-Content -Path $PPKLoader -Value $CurrentPPKList -ErrorAction Stop
        }
        catch 
        {
            throw "Failed to add the key to the auto loader list at $PPKLoader."
        }
    }
    else
    {
        Write-Verbose "Looks like we're setting up our autoloader for the first time, let's create a list."
        try 
        {
            New-Item $PPKLoader -Value $KeyPath -ItemType File -ErrorAction Stop | Out-Null
            $CurrentPPKList = @($KeyPath)
        }
        catch 
        {
            throw "Failed to create the PPKLoader file at $PPKLoader"
        }
    }
    if ((Get-Process -Name pageant -ErrorAction SilentlyContinue))
    {
        try 
        {
            Stop-Process -Name pageant | Out-Null
        }
        catch 
        {
            Write-Error "Failed to stop running pageant process, trying to continue anyway" # soft fail
        }
        
    }
    Write-Verbose "Attempting to start Pageant with $CurrentPPKList"
    try 
    {
        Start-Process pageant -ArgumentList $CurrentPPKList -ErrorAction Stop
    }
    catch 
    {
        throw "Failed to start pageant with keylist.$($_.Exception.Message)" # fail incase our key isn't valid. I doubt we'll get an exception message.
    }
    # Create our Pageant startup shortcut
    $PageantStartupLocation = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\pageant.lnk"
    $PageantLocation = (Get-Command pageant).Source
    if ((Test-Path $PageantStartupLocation))
    {
        try
        {
            Remove-Item $PageantStartupLocation -Confirm:$false -Force -ErrorAction Stop
        }
        catch
        {
            throw "Failed to remove existing pageant startup shortcut.`n$($_.Exception.Message)"
        }
    }
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($PageantStartupLocation)
    $Shortcut.TargetPath = $PageantLocation
    $Shortcut.Arguments = $CurrentPPKList | Out-String
    $Shortcut.Description = "Start pageant with preloaded keys"
    $Shortcut.Save()
}