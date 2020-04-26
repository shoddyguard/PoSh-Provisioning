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
    General notes
#>
function Import-JSON
{
    [CmdletBinding()]
    param
    (
        # The path to the JSON file
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Path
    )

    function Convert-JSONObjects
    {
        param( $Object )
        $Compiled = $null
        $ObjectName = $Object.GetType().Name
        switch ($ObjectName) 
        {
            "PSCustomObject" 
            { 
                Write-Verbose "Type seems to be PSCustomObject, converting to hashtable"
                $Compiled = @{ }
                $Object.psobject.properties | ForEach-Object { 
                    $Compiled[$_.Name] = Convert-JSONObjects -Object $_.Value 
                } # Do some recursion to get nested objects
            }
            "Object[]"
            {
                $list = New-Object System.Collections.ArrayList
                Write-Verbose "Type seems to be an Array,"
                $Object | ForEach-Object {
                    $list.Add((Convert-JSONObjects -Object $_)) | Out-Null
                } # more recursion
                $Compiled = $list
            }
            Default
            {
                Write-Verbose "Object is $ObjectName and is currently unhandled."
                $Compiled = $Object
            }
        }
        return $Compiled
    }

    try
    {
        $json = Get-Content $Path -Raw -ErrorAction Stop
    }
    catch
    {
        throw "Failed to import JSON.`n$($_.Exception.Message)"
    }
    $FilteredJSON = Convert-JSONObjects -Object (ConvertFrom-Json $json)

    return $FilteredJSON
}