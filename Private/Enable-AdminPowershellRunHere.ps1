<#
.SYNOPSIS
    Adds "Run PowerShell as Administrator here..." to the shift+right click context menu
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
    I've been told that some systems have have trouble calling PowerShell to run Powershell, if that's you then you can use the alternative command below:
    "PowerShell -windowstyle hidden -Command `"Start-Process cmd -ArgumentList '/s,/k,pushd,%V && start PowerShell && exit' -Verb RunAs`""

#>
function Enable-AdminPowerShellRunHere 
{
    [CmdletBinding()]
    param (
        $CommandName = 'Open PowerShell here as Administrator...'
    )

    # I believe this covers us for every location that people would want to use this command...if not send me PR! :)
    $RegItems = @(
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\PowerShellAdmin",
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\PowerShellAdmin\command",
        "HKLM:\SOFTWARE\Classes\Directory\shell\PowerShellAdmin",
        "HKLM:\SOFTWARE\Classes\Directory\shell\PowerShellAdmin\command",
        "HKLM:\SOFTWARE\Classes\Drive\shell\PowerShellAdmin",
        "HKLM:\SOFTWARE\Classes\Drive\shell\PowerShellAdmin\command",
        "HKLM:\SOFTWARE\Classes\LibraryFolder\Background\shell\PowerShellAdmin",
        "HKLM:\SOFTWARE\Classes\LibraryFolder\Background\shell\PowerShellAdmin\command"
    )

    $RegValues = @{
        '(default)'    = $CommandName
        'Extended'     = ''
        'HasLUAShield' = ''
        'Icon'         = 'powershell.exe'
    }
    # Below logic was written at 10pm...it's probably waff, but it works. PR's welcome! :D
    foreach ($Item in $RegItems)
    {
        if ((Test-Path -LiteralPath $Item) -ne $true)
        {
            try 
            {
                New-Item $Item -Force -ErrorAction Stop | Out-Null # Force isn't as scary as I first thought, it basically just acts as recursive AFAICT
            }
            catch 
            {
                throw "Failed to create $Item"
            }
        }
        if ($Item -match '\\command')
        {
            $CommandSplat = @{
                LiteralPath = $Item
                Name        = '(default)'
                Value       = "PowerShell -windowstyle hidden -Command `"Start-Process Powershell -ArgumentList '-NoExit -Command Set-Location -LiteralPath %V' -Verb RunAs`"" # %V is a special parameter that gets passed when executing context menu stuff, it denotes "here"
                ErrorAction = 'Stop'
            }        
            if (!(Get-ItemProperty -Name '(default)' -LiteralPath $Item -ErrorAction SilentlyContinue))
            {
                try
                {
                    New-ItemProperty @CommandSplat -PropertyType String | Out-Null
                }
                catch
                {
                    throw "Failed to set command.`n$($_.Exception.Message)"
                }
                break
            }
            try 
            {
                Set-ItemProperty @CommandSplat
            }
            catch 
            {
                throw "Failed to set command.`n$($_.Exception.Message)"
            }
            break
        }
        foreach ($Val in $RegValues.GetEnumerator())
        {
            $ValSplat = @{
                LiteralPath = $Item
                Name        = $Val.key
                Value       = $Val.value
                ErrorAction = 'Stop'
            }
            if (!(Get-ItemProperty -Name $Val.key -LiteralPath $Item -ErrorAction SilentlyContinue))
            {
                try 
                {
                    New-ItemProperty @ValSplat -PropertyType String | Out-Null
                }
                catch 
                {
                    throw "Failed to set $($val.key) on $item.$($_.Exception.Message)"
                }
                break
            }
            try 
            {
                Set-ItemProperty @ValSplat
            }
            catch 
            {
                throw "Failed to set $($val.key) on $item.$($_.Exception.Message)"
            }
        }
    }
}