<#
.Synopsis
   Used to get up and running quickly on a new build.
.DESCRIPTION
   Sets up:
    * Enables 'Run as different user' on the start menu
    * £nabl3w 'Start PowerShell here as administrator...' on the extended context menu
    * Chocolatey Installation
    * Application installation (via Chocolatey)
    * RSAT Installation
    * GitHub SSH
    * GitHub GPG keys
    * Auto-loading PuTTY Keys
    * GitHub repo cloning
    * AppData symlinks
    * Installing VSCode Extensions
    * Removes desktop icons.
.EXAMPLE
   Initialize-NewBuild -ConfigurationFile C:\Config\Configuration.JSON -BuildType Home
.OUTPUTS
    Creates a permanent directory in %APPDATA%\ShoddyGuard\Provisioning currently only used by the PPK autoloader
.NOTES
    The following features require a cloud storage provider:
        * AppData symlinks
    TODO:
        Progress bars for sub-cmdlets (esp RSAT components!)
        Silence output of some more of commands, especially GitHub
        A lot of the steps have an erroraction stop or throw condition on them, this could probably be reduced to warnings/errors.
#>
function Initialize-NewBuild
{
    [CmdletBinding()]
    Param
    (
        # Path to the configuration file to use
        [Parameter(Mandatory = $false, ValuefromPipeline = $true, Position = 0, ParameterSetName = 'ConfigurationFile')]
        [string]
        $ConfigurationFile,
                
        # Which type of build we're working with
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfigurationFile')]
        [string]
        $BuildType,

        # Sets which type of SSH method to use
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfigurationFile')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [ValidateSet('OpenSSH', 'Putty')]
        [string]
        $GitSSHMethod,

        # The path to where you'd like your Git clones to end up
        [Parameter(Mandatory = $false)]
        [string]
        $SourceControlPath = 'C:\SourceControl',

        # The place where you'd like to store your PuTTY SSH keys
        [Parameter(Mandatory = $false)]
        [string]
        $PPKKeyPath = "$env:USERPROFILE\Keys",

        # If set will clear all icons on the desktop at the end of the script
        [Parameter(Mandatory = $false)]
        [switch]
        $ClearDesktopIcons

    )
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $false)
    {
        throw "$($MyInvocation.InvocationName) requires elevation to run."
    }
    # Configuration file parsing
    if ($ConfigurationFile)
    {
        if ($ConfigurationFile -match "^http")
        {
            try 
            {
                # Experimental #
                $tmpconfig = New-TemporaryFile -ErrorAction Stop
                Invoke-WebRequest -Uri $ConfigurationFile -OutFile $tmpconfig -ErrorAction Stop
                $ConfigurationFile = $tmpconfig
            }
            catch 
            {
                throw "Failed to download configuration file.`$($_.Exception.Message)"
            }
        }
        Write-Verbose "Attempting to import build configurations"
        try 
        {
            $BuildConfig = Import-JSON -Path $ConfigurationFile    
        }
        catch 
        {
            throw "Failed to import build configuration file"
        }
        finally
        {
            # Let's not clog up people's temp dirs needlessly
            if ($tmpconfig)
            {
                Remove-Item $tmpconfig -confirm:$false -force -erroraction SilentlyContinue
            }
        }
        $Build = $BuildConfig.Builds.$BuildType
        if (!$Build)
        {
            throw "Cannot find $BuildType in the config file. Are you sure your config file is valid?"
        }
        $choco_packages = $Build.ChocoPackages + $BuildConfig.CommonPackages
        $BuildRepos = $Build.GitRepos
        $CommonRepos = $BuildConfig.CommonRepos
        $admin_account = $Build.admin_account
        $domain = $Build.domain
        # $Admin_PoSh = $Build.Admin_Posh # Not used right now, planned for the future.
        $Name = $Build.GitName
        $InstallRSAT = $Build.RSAT
        $EmailAddress = $Build.GitEmail
        $GitSSHMethod = $Build.gitsshmethod
        $CloudStorage = $Build.CloudStorage
        if ($CloudStorage -match "^\$" )
        {
            Write-Verbose "CloudStorage contains a variable"
            $CloudStorage = Invoke-Expression $CloudStorage # actually might be better off just passing this in as a parameter?
            if (!$CloudStorage)
            {
                throw "It doesn't look like your cloud storage path is valid. Please make sure you've setup your cloud storage provider before starting this script."
            }
        }
        $PPKstoGen = $Build.ppks + $BuildConfig.CommonPPKS
        $CloudJunctions = $Build.OneDriveJunctions
        $VisualStudioExtensions = $Build.VSCodeExts + $BuildConfig.CommonVSCodeExts
    }
    else 
    {
        Write-Host "Currently this module doesn't support builds without a config file"
        throw "Coming soon..."
    }
    if ($CloudStorage)
    {
        $CloudStoragePath = "$CloudStorage\.provisioning"
        $JunctionsPath = "$CloudStoragePath\DataSync"
        $admin_powershellprofile = "$JunctionsPath\AdminPowerShellProfile\Microsoft.PowerShell_profile.ps1" ###### CHANGE THIS
    }
    if (!$GitSSHMethod)
    {
        throw "No git SSH method configured, please check your configuration file"
    }
    # Progress bar setup
    $TotalSteps = 11
    $StatusText = '"Step $($Step.ToString().PadLeft($TotalSteps.Count.ToString().Length)) of $($TotalSteps): $Task"'
    $ProgressID = 1
    $Activity = "Provisioning a new machine."
    $StatusBlock = [ScriptBlock]::Create($StatusText)
    
    # Do checks
    Write-Verbose "Checking everything is good before starting"
    $Task = "Checking prequisites"
    $Step = 1
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)

    if ($CloudStorage)
    {
        if (!(Test-Path $CloudStoragePath))
        {
            throw "It doesn't look like your cloud storage path is valid. Please make sure you've setup your cloud storage provider before starting this script."
        }
    }

    # Setup our directories
    # Perma dir
    $env:SGProvisionFolder = "$env:Appdata\ShoddyGuard\Provisioning"
    if (!(Test-Path $env:SGProvisionFolder))
    {
        Write-Verbose "Creating provisioner folder at $env:SGProvisionFolder"
        try 
        {
            New-Item $env:SGProvisionFolder -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch 
        {
            throw "Failed to create the storage directory"
        }
    }
    # Temp dir
    $tempname = ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 8 | ForEach-Object { [char]$_ }))
    Write-Verbose "Creating a temp folder ($tempname) for working files"
    try 
    {
        $env:TempSGProvisionerFolder = "$env:TEMP\$tempname"
        New-Item $env:TempSGProvisionerFolder -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch 
    {
        throw "Failed to create temp directory"
    }

    # Add "Run as different user" to start menu
    if ($admin_account)
    {
        Write-Verbose "Adding `"Run as differnt user`" to the context menu"
        $Step = 2
        $Task = "Adding `"Run as differnt user`" to the context menu"
        Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
        try
        {
            Enable-RunAsUser -ErrorAction Stop
        }
        catch
        {
            Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            throw "$($_.Exception.Message)"
        }    
    }

    # Add "Open PowerShell window here as Administrator..." to the right-click context menu
    Write-Verbose "Enabling `"Start PowerShell here as Administrator...`" on the extended context menu"
    $Step = 3
    $Task = "Enabling `"Start PowerShell here as Administrator...`" on the extended context menu"
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    try
    {
        Enable-AdminPowerShellRunHere -ErrorAction Stop
    }
    catch
    {
        Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        throw "$($_.Exception.Message)"
    }

    # Install Chocolatey followed by any applications we want
    Write-Verbose "Checking Chocolatey is installed"
    $Step = 4
    $Task = "Installing Chocolatey and any applications"
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    try
    {
        Start-SilentProcess -Program choco -ArgumentList "-?" -ErrorAction SilentlyContinue
    }
    catch
    {
        $ChocoInstall = $true
        Write-Verbose "Chocolatey requires installation"
    }
    if ($ChocoInstall -eq $true)
    {
        try 
        {
            Install-Chocolatey -ErrorAction Stop
        }
        catch 
        {
            Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            throw "Failed to install Chocolatey.`n$($_.Exception.Message)"
        }
        Write-Verbose "Reloading PATH as it has changed"
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    Write-Verbose "Installing applications"
    try 
    {
        Install-ChocolateyPackages -Packages $choco_packages -ErrorAction Stop
    }
    catch 
    {
        Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        throw "Failed to install Chocolatey packages.`n$($_.Exception.Message)"
    }

    # Install RSAT
    If ($InstallRSAT -eq $true)
    {
        Write-Verbose "Installing RSAT"
        $Step = 5
        $Task = "Installing RSAT"
        Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
        try 
        {
            Install-RSAT -ErrorAction Stop
        }
        catch 
        {
            Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            throw "Failed to install RSAT.$($_.Exception.Message)"
        }
    }

    # Get SSH for GitHub sorted so we can do work
    $Task = "Setting up GitHub SSH"
    $Step = 6
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    Write-Host "We will now create a keypair for you to use to authenticate to GitHub.`nUser interaction will be required."
    try 
    {
        New-GitHubKeyPair -SSHProvider $GitSSHMethod
    }
    catch 
    {
        Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        throw "Failed to create GitHub keypair.`n$($_.Exception.Message)"
    }

    Write-Verbose "Creating source control folder"
    if (!(Test-Path $SourceControlPath))
    {
        try 
        {
            New-Item $SourceControlPath -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch 
        {
            Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            throw "Failed to create new source control directory.`n$($_.Exception.Message)"
        }
    }
    
    # Clone the repos we care about here
    Write-Verbose "Cloning any GitHub repos we care about"
    $Step = 7
    $Task = "Cloning supplied GitHub repositories"
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    if ($BuildRepos)
    {
        try
        {
            Add-GitHubRepos -RepoHash $BuildRepos -Path $SourceControlPath -ErrorAction Stop
        }
        catch
        {
            Write-Error "$($_.Exception.Message)" # soft fail
        }
    }
    if ($CommonRepos)
    {
        Write-Verbose "Cloning common repos"
        try
        {
            Add-GitHubRepos -RepoHash $CommonRepos -Path $SourceControlPath -ErrorAction Stop
        }
        catch
        {
            Write-Error "$($_.Exception.Message)" # soft fail
        }
    }
    
    # PuTTYgen a new key pair for us to use to connect to things
    $Step = 8
    $Task = "Setting up auto-loading PuTTY keypairs"
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    if ($PPKstoGen)
    {
        $PPKCount = $PPKstoGen | Measure-Object | Select-Object -ExpandProperty Count # simply counting the array results in an "off-by-one" error
        Write-Verbose "Generating new PuTTY Key Pair"
        # We need to do this a couple of times to get the keys for Puppet master etc
        Write-Host "We need to generate some PuTTY keypairs to authenticate you against things" -ForegroundColor Yellow
        Write-Host "Looks like you need to generate $($PPKCount) keys:"
        $PPKstoGen
        Start-Sleep -Seconds 5
        foreach ($PPK in $PPKstoGen)
        {
            if (!$PPK)
            {
                # not sure how this happening but sometimes powershell is pulling in an empty string.
                # may need to revisit if we ever populate "common ppks"
                continue    
            }
            Write-Host "Generating $($PPK)"
            try 
            {
                New-AutoLoadingPPK -KeyPath $PPKKeyPath -Keyname ($PPK -replace " ", "") -ErrorAction Stop # ensure we've got a sensible filename
            }
            catch 
            {
                Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
                throw "$($_.Exception.Message)"
            }
        }
    }

    # Create a signing key for GitHub
    Write-Verbose "Setting up GPG signing key"
    $Step = 9
    $Task = "Setting up GPG signing key"
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    try 
    {
        New-GPGKey -EmailAddress $EmailAddress -Name $Name -ErrorAction Stop
    }
    catch 
    {
        Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        throw "$($_.Exception.Message)"
    }

    # Will need to run the admin command as another user
    if ($admin_account)
    {
        try
        {
            Update-AdminPSProfile -Username $admin_account -SourcePath $admin_powershellprofile -domain $domain

        }
        catch
        {
            Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            throw "Failed to copy PoSh profile for $admin_account.`n$($_.Exception.Message)"
        }
    }
    $Step = 10
    $Task = "Installing VS Code extensions"
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    if ($VisualStudioExtensions)
    {
        Write-Verbose "Installing VSCode Extensions"
        foreach ($extension in $VisualStudioExtensions)
        {
            try 
            {
                Start-Process code -ArgumentList "code --install-extension $extension" -Wait -NoNewWindow -ErrorAction Stop    
            }
            catch
            {
                Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
                throw "Failed to install VSCode extension $extension.`n$($_.Exception.Message)"
            }
        }
    }
    $Step = 11
    $Task = "Creating Symlinks with cloud storage"
    Write-Progress -Id $ProgressID -Activity $Activity -Status (& $StatusBlock) -CurrentOperation $Task -PercentComplete ($Step / $TotalSteps * 100)
    # Copy any settings that we want to be kept between the two.
    if ($CloudJunctions)
    {
        foreach ($Junction in $CloudJunctions.GetEnumerator())
        {
            $Source = "$JunctionsPath\$($Junction.key)"
            $Destination = $Junction.Value
            if ($Junction.Value -match "^\$")
            {
                # We'll need to split the sting up so we can get the expressionable part and non-expressionable part
                # This sucks but it does have the advantage of allowing us to be able to plop $variables in the config file.
                # I am not good at regex so I hope this is ok, send me a PR if you've got a better method! :)
                $var = [regex]::match($Junction.Value, '^\$[\w]+[:|\w][\w]+').Groups[0].Value
                $path = $Junction.Value -split '^\$[\w]+[:|\w][\w]+'
                $Destination = Invoke-Expression $var
                if ($path -ne "")
                {
                    $Destination = "$($Destination)$($path[1])" # for some reason path is being split into 2 bits :shrug:
                }
            }
            Write-Verbose "Linking $Source to $($Junction.value)"
            try
            {
                New-OneDriveJunction -OneDriveSource $Source -LocalDestination $Destination -ErrorAction Stop
            }
            catch 
            {
                Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
                throw "$($_.Exception.Message)"
            }
        }
    }

    if ($ClearDesktopIcons)
    {
        $Profiles = @("$env:PUBLIC", "$env:USERPROFILE")
        foreach ($Profile in $Profiles)
        {
            try
            {
                Get-ChildItem "$Profile\Desktop\*" -Include *.lnk | Remove-Item -Force -Confirm:$false
            }
            catch
            {
                Write-Error "Failed to clear desktop shortcuts.`n$($_.Exception.Message)" # Soft fail
            }
        }
    }
    Remove-Item $env:TempSGProvisionerFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
}