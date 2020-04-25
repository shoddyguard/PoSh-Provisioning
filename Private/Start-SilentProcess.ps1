<#
.SYNOPSIS
    Runs a process but with tidier output
.DESCRIPTION
    I found that running certain processes via the Start-Process tool would result in some odd behaviour when dealing with stderr and stdout.
    This is particularly true of commands/programs written for the command line instead of PowerShell and those running via some form of BASH emulation.
    Mostly this resulted in things such as `Out-Null` and exit codes not working properly.
    For example when running a `Start-Process bundle -arguments exec rake foo:bar` it became impossible to mute stdout as rake would always print to stderr (even for succesful execution) and the exit code would always be a success even on a failure making try/catch impossible.
    This could be worked around using call operator such as `& bundle exec rake foo:bar 2> null` along with `$lastexitcode` but there's no way to recover stderr unless you output `2>` to a file and read it back.
    This cmdlet aims to capture both stdout and stderr along with the exit code in variables allowing us to be clever with what we do and don't display - along with error handling.
    This means that we can surpress stdout/stderr and only display them if we're running `-verbose` and if we get a non-zero exit code then we can grab stderr and pop that in.
    Given that rake still outputs a lot of it's stdout to stderr this will still result in some noise on non-zero exits, but this should be ok.
.EXAMPLE
    Start-SilentProcess -Program bundle -ArgumentList exec rake foo:bar
    
    This would run the `bundle` command and pass in any arguments from the `-ArgumentList`, all output would be surpressed unless there is an error
.EXAMPLE
    Start-SilentProcess -Program c:\temp\myprog.exe -ArgumentList "foo" -Verbose

    This woud run the `myprog.exe` program and pass in the arguments from `-ArgumentList`, real-time output would be surpressed but a verbose dump of any output (stdout or stderr) would provided at the end.
.EXAMPLE
    Start-SilentProcess myprog -ArgumentList "args" -RedirectOutput:$false

    This would run `myprog.exe` with the supplied arguments, all output would be visible.
.NOTES
    Todo:
#>
function Start-SilentProcess 
{
    [CmdletBinding()]
    param 
    (
        # The program to be run (if program name is used it must be available in PATH)
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]
        $Program,
        # The list of arguments to pass to the program
        [Parameter(Mandatory = $true)]
        [string]
        $ArgumentList,
        # The working directory to use, if none specified uses the current location
        [Parameter(Mandatory = $false)]
        [ValidateScript( {
                if (!(test-path $_))
                {
                    throw "$_ does not appear to be a vaild path"
                }
                else 
                {
                    $true    
                }
            })]
        [string]
        $WorkingDirectory = (Get-Location | Select-Object -ExpandProperty Path | Convert-Path),
        # Redirects stdout and stderr to variables
        [Parameter(Mandatory=$false)]
        [bool]
        $RedirectOutput = $true,
        # Accepted exit codes for the program (for those that spit out non-zero exit code)
        [Parameter(Mandatory=$false)]
        [array]
        $ValidExitCodes = @(0)
    )
    try 
    {
        $FileName = (Get-Command $Program -ErrorAction Stop).path    
    }
    catch 
    {
        throw "Failed to find specified program.`n$($_.Exception.Message)"
    }
    if (($RedirectOutput -eq $false) -and ($VerbosePreference -ne "SilentlyContinue"))
    {
        Write-Warning "Verbose preference being ignored as `$RedirectOutput is set to `$false"
    }
    $ProcessObj = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessObj.FileName = $FileName
    $ProcessObj.WorkingDirectory = $WorkingDirectory
    if ($RedirectOutput -eq $true)
    {
        $ProcessObj.RedirectStandardError = $true
        $ProcessObj.RedirectStandardOutput = $true
    }
    $ProcessObj.UseShellExecute = $false # does this need to change with the above?
    $ProcessObj.Arguments = $ArgumentList
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessObj
    $Process.Start() | Out-Null
    if ($RedirectOutput -eq $true)
    {
        $stdout = $Process.StandardOutput.ReadToEnd()
        $stderr = $Process.StandardError.ReadToEnd()
    }
    $Process.WaitForExit()
    Write-Debug "Exit code: $($Process.ExitCode)"
    if ($Process.ExitCode -notin $ValidExitCodes)
    {
        $ErrMsg = "Program returned an unsupported exit code: $($Process.ExitCode)"
        if ($stderr)
        {
            $ErrMsg += "`nMessage: $stderr"
        }
        throw $ErrMsg
    }
    # I think this is what we want? 
    # Basically only return output if we've got -Verbose set and if we've got RedirectOutput set as otherwise we'll either not after the output or be getting it via the console in real-time.
    if (($VerbosePreference -ne "SilentlyContinue") -and $RedirectOutput -eq $true)
    {
        $RetStr = $stdout
        if ($stderr)
        {
            $RetStr += $stderr
        }
        Write-Verbose $RetStr
    }
}
