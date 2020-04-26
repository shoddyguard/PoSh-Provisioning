<#
.SYNOPSIS
    Creates an RSA keypair to be used for GitHub
.DESCRIPTION
    OpenSSH is very basic.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function New-GitHubKeyPair
{
    [CmdletBinding()]
    param 
    (
        # Which method to use for SSH
        [Parameter(Mandatory = $true)]
        [validateset('OpenSSH', 'Putty')]
        [string]
        $SSHProvider,

        # Not in use (yet)
        [Parameter(Mandatory = $false)]
        [ValidateSet('GitHub','BitBucket','GitLab')]
        [string]
        $GitProvider = 'GitHub'
    )
    $SSHPath = "$env:USERPROFILE\.ssh"
    Write-Verbose "SSH path set to $SSHPath"
    if (!(Test-Path $SSHPath))
    {
        try 
        {
            New-Item $SSHPath -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "Failed to create SSH diretory.$($_.Exception.Message)"    
        } 
    }

    switch ($SSHProvider)
    {
        "OpenSSH" 
        {
            Write-Verbose "Generating new OpenSSH keypair"
            $SSHKeyWin = "$sshpath\id_rsa"
            # ssh-keygen now looks like it accepts Windows paths, the below is left in for posterity
            #$DriverLetter = $env:SystemDrive -replace ":"
            #$SSHKeyUnix = ("/"+$DriverLetter+("$env:USERPROFILE\.ssh" -replace "^C:\\|[\\]","/")+"/"+"test_key").ToLower()
            if (Test-Path $SSHKeyWin)
            {
                Write-Verbose "SSH key already exists in $SSHKeyWin. Skipping"
                break
            }
            $CommandArgs = "-t rsa -b 2048 -f $SSHKeyWin -q -N `"`""
            try 
            {
                Start-Process "ssh-keygen" -ArgumentList $CommandArgs -Wait -NoNewWindow    
            }
            catch 
            {
                throw "Failed to generate SSH keypair"    
            }
            # It's unlikely the above will generate an stderr so we'll account for that here
            try 
            {
                $ssh_pub = Get-Content "$SSHKeyWin.pub" -Raw -ErrorAction Stop
            }
            catch 
            {
                throw "Failed to access $SSHKeyWin. Are you sure it was created succesfully?"
            }
            Write-Host "Please copy the following SSH key into GitHub"
            Start-Sleep -Seconds 5
            Write-Host $ssh_pub
            Read-Host "Press enter to continue..."
            Write-Host "Attempting to connect to GitHub, if this is your first time connecting you WILL prompted to check the fingerprint."
            Read-Host "Press enter to continue..."
            try 
            {
                Start-Process "ssh" -ArgumentList "-T git@github" -NoNewWindow -Wait -ErrorAction Stop
            }
            catch 
            {
                throw "Failed to connect to GitHub.`n$($_.Exception.Message)"
            }
            

        }
        "Putty" 
        {
            Write-Verbose "Generating new PuTTY keypair"
            $KeyPath = "$SSHPath\GitHub.ppk"
            if (Test-Path $KeyPath)
            {
                Write-Verbose "Key already exists at $KeyPath. Skipping"
                break
            }
            # Unfotunately Putty doesn't support command line input on Windows (https://www.chiark.greenend.org.uk/~sgtatham/putty/wishlist/puttygen-batch.html)
            # maybe in the future look at using it via cygwin on WSL, but for now this will suffice
            try
            {
                New-AutoLoadingPPK -KeyPath $SSHPath -KeyName "GitHub" -ErrorAction Stop
            }
            catch
            {
                throw "$($_.Exception.Message)"
            }
            Read-Host "Press enter once the public key has been copied to your GitHub account..."
            Write-Verbose "Setting GIT_SSH environment variable"
            # at somepoint maybe set system-wide with an admin check, but for now this will suffice
            try 
            {
                $PLinkPath = (Get-Command plink -ErrorAction Stop).Source
            }
            catch 
            {
                throw "Failed to find Plink. Are you sure Putty is installed?"
            }
            try 
            {
                $env:GIT_SSH = $PLinkPath
                [System.Environment]::SetEnvironmentVariable('GIT_SSH', $PLinkPath, [System.EnvironmentVariableTarget]::User)
            }
            catch 
            {
                throw "Failed to set GIT_SSH environment variable."
            }
            Write-Host "Attempting to connect to GitHub, if this is your first time connecting you WILL be prompted to check the fingerprint"
            Read-Host "Press enter to continue..."
            try 
            {
                Start-Process plink -ArgumentList "-agent -v git@github.com" -Wait -NoNewWindow -ErrorAction Stop # this didn't generate an error when I forgot to add my GH key. We should try Start-SilentProcess here.
            }
            catch
            {
                throw "$($_.Exception.Message)"
            }
        }
    }
    <# Coming soon...
    # Do a test GitClone
    Write-Output "Cloning test repo"
    try 
    {
        Start-Process "git" -ArgumentList "clone $test_repo" -WorkingDirectory $env:BSProvisionerFolder -NoNewWindow -Wait -ErrorAction Stop
    }
    catch 
    {
        throw "Failed to clone test repo.$($_.Exception.Message)"
    }
    #>
}