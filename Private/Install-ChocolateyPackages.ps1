<#
.SYNOPSIS
    Installs Chocolatey packages if not installed
.DESCRIPTION
    Very simple cmdlet for installing chocolatey packages, it's not really meant to be used on it's own
.EXAMPLE
    Install-ChocolateyPackages -Packages $Packages
.INPUTS
    $Packages - should be an object with headers of `name` and `version`
.NOTES
    Unlike other cmdlets in this collection I've decided to have this one write-output with the packages being installed.
    Reason being is that these are system-wide packages so have the potential to ruin people's day if installed.
    Todo:
        Actually make version support work :facepalm:
#>
function Install-ChocolateyPackages
{
    [CmdletBinding()]
    param 
    (
        $Packages
    )
    $DefaultProcessParams = @{
        RedirectOutput = $true
        ValidExitCodes = @(0,3010,1641) # 3010 and 1641 are success but restart pending/initiated
    }
    if ($VerbosePreference -ne "SilentlyContinue")
    {
        $OutputMode = 'Out-Default'
        $DefaultSilentProcessParams['RedirectOutput'] = $false
    }
    Write-Verbose "Ensuring all pre-requisite Chocolatey packages are installed"
    foreach ($Package in $Packages.GetEnumerator())
    {
        Write-Verbose "Checking to see if $($Package.name) is installed"
        # Start-Process does weird stuff with stdout so I'm doing things very simply...
        $testPackage = choco list $Package.name -e -r --local-only
        # We won't autoupdate packages that aren't on latest automagically as it may break stuff elsewhere for people.
        if ($testPackage)
        {
            Write-verbose "$($Package.name) is installed, checking version number"
            $VersionCheck = $testPackage -replace "$($Package.name)|", ""
            switch ($Package.value.tolower()) 
            {
                "" {  }
                "latest" {  }
                "present" { }
                Default 
                {
                    if ($_ -ne $VersionCheck)
                    {
                        throw "Package: $($Package.name) requires version $($Package.value) but $VersionCheck is installed"
                    }
                    $Version = $Package.value.tolower()
                }
            }
            Write-Verbose "Version $VersionCheck should be supported"
        }
        else
        {
            Write-Verbose "$($Package.name) requires installation"
            $InstallArgs = "install $($Package.name) -y -r"
            if ($Version)
            {
                $InstallArgs = "install $($Package.name) --version $Version -y -r"
            }
            try 
            {
                Write-Output "Installing $($Package.name) | $($Package.value)"
                Start-SilentProcess choco -ArgumentList $InstallArgs @DefaultProcessParams
            }
            catch 
            {
                throw "Failed to install $($Package.name).`n$($_.Exception.Message)"
            }
        }
        # Would be good to check if PATH has changed instead of just blindly assuming it has?
        # We maybe don't need the verbose output here as it'll get noisy...
        Write-Verbose "$($Package.name) installed, reloading PATH in case it has changed"
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User") 
    }
}
