<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    ToDo:
        Make wording more generic
#>
function New-OneDriveJunction
# https://blog.usejournal.com/what-is-the-difference-between-a-hard-link-and-a-symbolic-link-8c0493041b62
{
    [CmdletBinding()]
    param 
    (
        # The folder in OneDrive you want to link
        [Parameter(Mandatory = $true)]
        [string]
        $OneDriveSource,

        # The destination file on the local machine
        [Parameter(Mandatory = $true)]
        [string]
        $LocalDestination
    )

    if (!(Test-Path $OneDriveSource))
    {
        throw  "Path: $OneDriveSource does not exist"
    }
    $Params = @{
        ItemType    = "HardLink"
        Path        = $OneDriveSource
        Target      = $LocalDestination
        ErrorAction = "Stop"
    }
    If ((Get-Item $OneDriveSource).PSIsContainer)
    {
        $Params.ItemType = "Junction" # this doesn't require admin privs, symlink does.
    }
    # Very rudimentary way of ensuring the folder structure is in place
    $PotentialParent = Split-Path $LocalDestination
    if (!(Test-Path $PotentialParent))
    {
        Write-Verbose "No parent directory found for $LocationDestination.`nCreating $PotentialParent"
        try
        {
            New-Item -Path $PotentialParent -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "Failed to create parent.$($_.Exception.Message)"
        }
    }
    # First up we need to copy the file to the local machine, as if our OneDrive ever gets delinked things will break rather spectacularly
    try 
    {
        Write-Verbose "Moving $OneDriveSource to $LocalDestination"
        Move-Item -Path $OneDriveSource -Destination $LocalDestination -Force -ErrorAction Stop | Out-Null # Setting the force flag so we overwrite any base config that gone done as part of a package installation
    }
    catch 
    {
        throw "Failed to copy $OneDriveSource to local path $LocalDestination.$($_.Exception.Message)"    
    }
    try 
    {
        Write-Verbose "Creating symlink for $OneDriveSource."
        New-Item @Params | Out-Null
    }
    catch 
    {
        throw "Failed to create symlink.`n$($_.Exception.Message)"
    }
}