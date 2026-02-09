param($WorkerId, $TaskListFile, $GodotPath, $IsolationDir, $LogFile, $Strict)
$ErrorActionPreference = 'Stop'

if ($IsLinux) {
    $env:HOME = $IsolationDir
    $env:XDG_DATA_HOME = "$IsolationDir/.local/share"
    $env:XDG_CONFIG_HOME = "$IsolationDir/.config"

    New-Item -ItemType Directory -Path $env:XDG_DATA_HOME -Force | Out-Null
    New-Item -ItemType Directory -Path $env:XDG_CONFIG_HOME -Force | Out-Null
} else {
    $env:APPDATA = "$IsolationDir\AppData\Roaming"
    $env:LOCALAPPDATA = "$IsolationDir\AppData\Local"

    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
}

Add-Content -Path $LogFile -Value "--- WORKER $WorkerId STARTED ---"

$Tasks = Get-Content $TaskListFile | ConvertFrom-Json
$FailCount = 0

foreach ($task in $Tasks) {
    Add-Content -Path $LogFile -Value "Running: $($task.Name)"
    
    $ArgsList = @("--headless")
    if ($task.Type -eq "script") { $ArgsList += "-s" }
    $ArgsList += $task.Path
    
    # Run Godot using cmd /c wrapper for reliable exit code and output capture
    $CmdArgs = $ArgsList -join ' '
    Add-Content -Path $LogFile -Value "DEBUG: Invoking cmd /c `"$GodotPath`" $CmdArgs"
    
    try {
        # Capture output to variable. 2>&1 ensures stderr is captured too.
        # We invoke cmd /c to ensure the exit code is propagated correctly to $LASTEXITCODE
        # Relax ErrorActionPreference to prevent stderr from triggering Try/Catch
        $OldEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        
        if ($IsLinux) {
            # Linux (PowerShell Core): Direct invocation usually captures exit codes correctly
            Add-Content -Path $LogFile -Value "DEBUG: Invoking directly `"$GodotPath`" $CmdArgs"
            $Output = & $GodotPath $ArgsList 2>&1
        } else {
            # Windows: cmd /c wrapper needed for some exit code edge cases
            Add-Content -Path $LogFile -Value "DEBUG: Invoking cmd /c `"$GodotPath`" $CmdArgs"
            $Output = & cmd /c "`"$GodotPath`" $CmdArgs" 2>&1
        }
        $ExitCode = $LASTEXITCODE
        
        $ErrorActionPreference = $OldEAP
        
        # Sanitize Output: Convert ErrorRecords (from stderr) to raw strings
        $CleanLines = @()
        foreach ($o in $Output) {
            if ($o -is [System.Management.Automation.ErrorRecord]) {
                if ($o.TargetObject -is [string]) {
                     $CleanLines += $o.TargetObject
                } else {
                     $CleanLines += $o.Exception.Message
                }
            } else {
                $CleanLines += $o
            }
        }
        $OutputText = $CleanLines -join "`n"
        
        Add-Content -Path $LogFile -Value $OutputText
        Add-Content -Path $LogFile -Value "DEBUG: ExitCode: $ExitCode"
        
        if ($ExitCode -ne 0) {
            Add-Content -Path $LogFile -Value "❌ FAILURE in $($task.Name) (Exit Code: $ExitCode)"
            $FailCount++
        } elseif ($Strict) {
             # Strict Analysis to match legacy behavior
             $StrictFail = $false
             
             # Sanitize known benign errors from text first
             # Remove "resources still in use" errors via regex replacement
             $CheckText = $OutputText -replace "ERROR: \d+ resources still in use at exit.*", ""
             $CheckText = $CheckText -replace "at: clear \(core/io/resource\.cpp:\d+\)", ""
             # Also sanitize warning
             $CheckText = $CheckText -replace "WARNING: ObjectDB instances leaked at exit.*", ""
             $CheckText = $CheckText -replace "at: cleanup \(core/object/object\.cpp:\d+\)", ""
             
             $Lines = $CheckText -split "`n"
             foreach ($RawLine in $Lines) {
                 $Line = $RawLine.Trim()
                 if ([string]::IsNullOrWhiteSpace($Line)) { continue }
                 
                 # Check for Critical Errors
                 if ($Line -match "ERROR:" -or $Line -match "SCRIPT ERROR:" -or $Line -match "\bFAIL\b" -or $Line -match "FAIL \[") {
                     Add-Content -Path $LogFile -Value "❌ STRICT FAILURE in $($task.Name) (Logs contain ERROR/WARNING/FAIL)"
                     Add-Content -Path $LogFile -Value "DEBUG: Trigger Line: '$Line'"
                     $StrictFail = $true
                     break
                 }
             }
             
             # Warnings (Filter Benign)
             if (-not $StrictFail -and $CheckText -match "WARNING:") {
                 $Lines = $CheckText -split "`n"
                 foreach ($Line in $Lines) {
                     if ($Line -match "WARNING:") {
                         # Explicit allow list for any other warnings if needed
                         $StrictFail = $true
                         Add-Content -Path $LogFile -Value "⚠️ STRICT WARNING: $Line"
                         break
                     }
                 }
             }
             
             if ($StrictFail) {
                 $FailCount++
             }
        }
    } catch {
        Add-Content -Path $LogFile -Value "❌ EXECUTION EXCEPTION: $_"
        $FailCount++
    }
}

Add-Content -Path $LogFile -Value "DEBUG: Worker Finished. FailCount: $FailCount"
exit $FailCount
