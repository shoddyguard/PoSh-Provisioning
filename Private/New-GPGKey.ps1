<#
.SYNOPSIS
    Generates a new GPG key and sets it as your default
.DESCRIPTION
    Creates a GPG key pair using Gpg4Win and sets is as your global default signing key.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    This is pretty dumb and doesn't do much in the way of checking things, it will always just set things.
    If there's already a key in use, this will replace it GLOBALLY.
    I'm not really sure what I'm doing here, feel free to submit a PR if you can improve this! :)
    Todo:
        Output GPG to a file instead so we don't constantly overwrite it.
#>
function New-GPGKey 
{
    [CmdletBinding()]
    param 
    (
        # Your name
        [Parameter(Mandatory = $true)]
        [String]
        $Name,

        # The email address of your user
        [Parameter(Mandatory = $true)]
        [string]
        $EmailAddress
    )
    # I couldn't find a way to do this without creating a file, and I can't be bothered to work out another method when this is working for now.
    $FileContent = "%no-protection
    Key-Type: default
    Subkey-Type: default
    Name-Real: $Name
    Name-Email: $EmailAddress
    Expire-Date: 0"
    Write-Verbose $FileContent
    try 
    {
        Get-Command gpg -ErrorAction Stop
    }
    catch 
    {
        throw "Gpg4win not found. Gpg4win is required to setup GPG keys"
    }
    try
    {
        New-Item -Path $env:TempSGProvisionerFolder -Name gpg.txt -Value $FileContent -ErrorAction Stop | Out-Null
    }
    catch
    {
        throw "Failed to create temporary file.`n$($_.Exception.Message)"
    }
    Write-Host "Generating new GPG key from $env:TempSGProvisionerFolder\gpg.txt.`nThis will take around 15 seconds"
    try 
    {
        Start-Process "gpg" -ArgumentList "--batch --generate-key $env:TempSGProvisionerFolder\gpg.txt" -NoNewWindow -ErrorAction Stop # this hung during testing so I've dropped the out-null for the next clean PC to test I wonder if having -Wait on for the first run causes issues. We may need to just run the command?
        Start-Sleep 15 # Sleep for 15 seconds to see if that fixes our issue - should give enough time for the key to be generated. Could also try a dry run of GPG before running the command?
    }
    catch 
    {
        throw "$($_.Exception.Message)"
    }
    # could potentially do something with gpg: revocation certificate stored as 'C:/Users/steve.brown/AppData/Roaming/gnupg/openpgp-revocs.d\4A95E1BB6033A514F79531F60D02E3E6C5860A2E.rev
    $keys = gpg --list-secret-keys --keyid-format LONG
    $gpg_dateformat = Get-Date -Format yyyy-MM-dd
    foreach ($line in $keys)
    {
        if (($line -match '^sec') -and ($line -match $gpg_dateformat)) # keeps the chances of finding more than one quite small
        { 
            # Filter out the extra guff
            $key = $line -replace "^sec   rsa\d\d\d\d\/| \d\d\d\d-\d\d-\d\d \[SC\]", ""   
        }
    }
    gpg --armor --export $key
    Write-Host "Please copy the above key to your GitHub GPG keys" -ForegroundColor Yellow
    Read-Host "Press enter to continue"
    git config --global commit.gpgsign true
    git config --global user.signingkey $key
    git config --global user.email $EmailAddress
    git config --global user.name $Name
}