<#
.SYNOPSIS
    Clones GitHub repositories to a given folder.
.DESCRIPTION
    Takes a hash of GitHub repos and parent folder names then clones said repo(s) into said folder(s)
.EXAMPLE
    PS C:\> Add-GitHubRepos -RepoHash @{"Work" = @('git@github.com:my-corp/bar.git','git@github.com:my-corp/foo.git') "Home" = @(git@github.com:fizz/buzz.git)} -Path C:\Git
    This would clone the `bar` repo into C:\Git\Work\bar, the `foo` repo into C:\Git\Work\foo and the `buzz` repo into C:\Git\Home\buzz
.NOTES
    Todo:
        Make this more generic (i.e not GitHub focused)
#>
function Add-GitHubRepos
{
    [CmdletBinding()]
    param 
    (
        # A hash of the repo and where you want it to end up
        [Parameter(Mandatory = $true)]
        [hashtable]
        $RepoHash,

        # The path to the root of your source control directory
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    foreach ($Key in $RepoHash.Keys)
    {
        # I couldn't think of a better way to work through our hashtable...if anyone comes up with a better method send me a PR!
        $CloneRoot = "$Path\$Key"
        If (!(Test-Path $CloneRoot))
        {
            try
            {
                New-Item $CloneRoot -ItemType Directory -ErrorAction Stop | Out-Null
            }
            catch
            {
                throw "Failed to create $CloneRoot.`n$($_.Exception.Message)"
            }
        }
        $Repos = $RepoHash.$Key
        if ($Repos)
        {
            foreach ($Repo in $Repos)
            {
                Write-Host "Cloning $Repo in $CloneRoot"
                #  I don't know a lot about other git providers, hopeully this will be enough
                if ($Repo -notmatch "^git@")
                {
                    Write-Error "$Repo does not appear to be in SSH format. (git@github.com:foo/bar.git)"
                    break
                }
                try 
                {
                    Start-SilentProcess git -ArgumentList "clone $repo" -WorkingDirectory $CloneRoot -ErrorAction Stop
                }
                catch 
                {
                    if ($_.Exception.Message -match "already exists and is not an empty directory.")
                    {
                        Write-Warning "$Repo already exists in $CloneRoot, skipping"
                    }
                    else
                    {
                        throw "Failed to clone $($Repo).`n$($_.Exception.Message)"
                    }
                }
            }
        }
    }
}