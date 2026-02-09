# Run Tests Locally (Timeout Protected)
# Usage: .\tests\run_tests.ps1 [-Strict:$false]

param (
    [bool]$Strict = $true,
    [string[]]$Targets = @()
)

$GodotPath = "C:\Users\smili\Documents\Godot\Installs\Godot_v4.5.1-stable_win64.exe"
$TimeoutSeconds = 60
$LogFile = "test_log.txt"

# Clear Log File
"--- TEST RUN STARTED: $(Get-Date) ---" | Out-File -FilePath $LogFile -Encoding UTF8

if ($Targets.Count -gt 0) {
    Write-Host "Running Specific Targets: $Targets" -ForegroundColor Cyan
    $TestScenes = @()
    $TestScripts = @()
    
    foreach ($T in $Targets) {
        # Check if direct file path
        if (Test-Path $T) {
            $Item = Get-Item $T
            if ($Item.Extension -eq ".tscn") { $TestScenes += $Item }
            elseif ($Item.Extension -eq ".gd") { $TestScripts += $Item }
        }
        # Check if pattern/name
        else {
            $Matches = Get-ChildItem -Path "tests" -Recurse | Where-Object { $_.Name -like "*$T*" }
            foreach ($M in $Matches) {
                if ($M.Extension -eq ".tscn") { $TestScenes += $M }
                elseif ($M.Extension -eq ".gd") { $TestScripts += $M }
            }
        }
    }
    
    # Deduplicate and Filter Exclusions (Mocks/Utils should not run as tests)
    $TestScenes = $TestScenes | Select-Object -Unique | Where-Object { $_.Name -notlike "Mock*" -and $_.Name -notlike "*Utils*" }
    $TestScripts = $TestScripts | Select-Object -Unique | Where-Object { $_.Name -notlike "Mock*" -and $_.Name -notlike "*Utils*" }
}
else {
    Write-Host "Searching for All Tests..." -ForegroundColor Cyan
    $TestScenes = Get-ChildItem -Path "tests" -Filter "*.tscn" -Recurse | Where-Object { $_.Name -notlike "Mock*" -and $_.Name -notlike "*Utils*" }
    $TestScripts = Get-ChildItem -Path "tests" -Filter "*.gd" -Recurse | Where-Object { $_.Name -notlike "Mock*" -and $_.Name -notlike "*Utils*" -and $_.Name -notlike "TestSafeGuard.gd" -and $_.Name -notlike "LeakDetector.gd" -and $_.Name -notlike "check_user_dir.gd" }
}

$GlobalExitCode = 0

function Run-GodotTest {
    param($Name, $Arguments)
    
    Write-Host "Running: $Name" -ForegroundColor Yellow
    
    $TempLog = [System.IO.Path]::GetTempFileName()
    
    try {
        # Using redirection to capture output for strict analysis
        # "godot" relies on PATH.
        $Command = "$GodotPath $Arguments > `"$TempLog`" 2>&1"
        
        # Invoke via cmd /c to ensure redirection works if PowerShell parsing fights it
        # Actually in PS: cmd /c "godot args > file 2>&1"
        
        $Process = Start-Process -FilePath "cmd" -ArgumentList "/c $GodotPath $Arguments > ""$TempLog"" 2>&1" -NoNewWindow -PassThru
        
        try {
            $Process | Wait-Process -Timeout $TimeoutSeconds -ErrorAction Stop
            $ExitCode = $Process.ExitCode
        }
        catch {
            Write-Host "TIMEOUT in $Name (External Watchdog: ${TimeoutSeconds}s)" -ForegroundColor Red
            
            # Use taskkill to kill process tree (cmd -> godot) to release file handles
            if ($Process.Id) {
                taskkill /PID $Process.Id /T /F | Out-Null
            }
            
            $ExitCode = 1
            "TIMEOUT occurred." | Out-File -FilePath "$TempLog" -Append
        }
        
        if ($ExitCode -ne 0) {
            Write-Host "FAILURE in $Name (Exit Code: $ExitCode)" -ForegroundColor Red
            Write-Host "--- LOG START ---" -ForegroundColor Gray
            Get-Content $TempLog | Out-Host
            Write-Host "--- LOG END ---" -ForegroundColor Gray
            
            # Append to Master Log (Failure Case)
            "--- TEST: $Name (EXIT $ExitCode) ---" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            Get-Content $TempLog | Out-File -FilePath $LogFile -Append -Encoding UTF8
            "-------------------`n" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            
            Remove-Item $TempLog -ErrorAction SilentlyContinue
            return 1
        }
        
        # Append to Master Log (Success Case, pending Strict Check)
        "--- TEST: $Name ---" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        Get-Content $TempLog | Out-File -FilePath $LogFile -Append -Encoding UTF8
        "-------------------`n" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        
        # Strict Analysis (Only if requested)
        if ($Strict) {
            $Output = Get-Content $TempLog -Raw
            
            $StrictFail = $false
            
            # 1. Critical Errors (Always Fail)
            if ($Output -match "ERROR:" -or $Output -match "SCRIPT ERROR:" -or $Output -match "\bFAIL\b" -or $Output -match "FAIL \[") {
                $StrictFail = $true
            }
            
            # 2. Warnings (Filter Benign)
            if (-not $StrictFail -and $Output -match "WARNING:") {
                $Lines = $Output -split "`n"
                foreach ($Line in $Lines) {
                    if ($Line -match "WARNING:") {
                        # ALLOW LOOP: Benign Warnings
                        if ($Line -match "ObjectDB instances leaked at exit") { continue }
                        
                        $StrictFail = $true
                        break
                    }
                }
            }
            
            # FAIL conditions
            if ($StrictFail) {
                 Write-Host "STRICT FAILURE in $Name (Logs contain ERROR/WARNING/FAIL)" -ForegroundColor Magenta
                 Write-Host "--- LOG START ---" -ForegroundColor Gray
                 Get-Content $TempLog | Out-Host
                 Write-Host "--- LOG END ---" -ForegroundColor Gray
                 Remove-Item $TempLog -ErrorAction SilentlyContinue
                 return 1
            }
        }
        
        Remove-Item $TempLog -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "EXECUTION ERROR in $Name : $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $TempLog) { Remove-Item $TempLog }
        return 1
    }
    return 0
}

# Helper: Extract Script Path from TSCN or return GD path
function Get-ScriptPath {
    param($FileItem)
    
    if ($FileItem.Extension -eq ".gd") {
        return $FileItem.FullName
    }
    
    if ($FileItem.Extension -eq ".tscn") {
        # Simple scan: Find the script attached to the root node (simplified)
        # OR just finding ANY usage of a script in the tscn might be hint enough?
        # Better: Look for the script resource that is likely the test runner logic.
        # Usually: [ext_resource type="Script" path="res://tests/foo.gd" id="1"]
        # And root node: script = ExtResource("1")
        
        $Content = Get-Content $FileItem.FullName -Raw
        
        # 1. Find Root Node script ID
        # Looking for 'script = ExtResource("1")' or similar
        # Since it can be on a new line after the node tag, we search for the assignment.
        # This assumes the MAIN script is usually the one we care about.
        if ($Content -match 'script\s*=\s*ExtResource\("(\w+)"\)') {
            $ScriptId = $Matches[1]
            
            # 2. Find Resource Path for that ID
            # [ext_resource type="Script" path="res://..." id="..."]
            # Be careful with regex escaping
            $Pattern = '\[ext_resource type="Script" path="([^"]+)" id="' + $ScriptId + '"\]'
            if ($Content -match $Pattern) {
                # Convert res:// to absolute
                $ResPath = $Matches[1]
                return $ResPath.Replace("res://", "$PWD/").Replace("/", "\")
            }
        }
    }
    
    return $null
}

# Helper: Recursive check for Guard
function Test-HashWatchdogStatic {
    param($Path, $Depth=0)
    
    if ($Depth -gt 5) { return $false } # Recursion limit
    if (-not (Test-Path $Path)) { return $false }
    
    $Content = Get-Content $Path -Raw
    
    # 1. Direct Usage (Stricter)
    # Check for instantiation (.new) or script loading (.gd)
    if ($Content -match "TestSafeGuard\.new" -or $Content -match "TestSafeGuard\.gd" -or $Content -match "TestSafeGuard\.tscn") { return $true }
    # Also check if it's a class_name TestSafeGuard (if we are scanning the file itself, though unlikely for a test file)
    if ($Content -match "class_name\s+TestSafeGuard") { return $true }
    
    # 2. Inheritance
    # extends "res://..."
    if ($Content -match 'extends\s+"res://([^"]+)"') {
        $ParentPath = $Matches[1].Replace("res://", "$PWD/").Replace("/", "\")
        return Test-HashWatchdogStatic -Path $ParentPath -Depth ($Depth + 1)
    }
    
    # extends 'res://...' (single quotes)
    if ($Content -match "extends\s+'res://([^']+)'") {
        $ParentPath = $Matches[1].Replace("res://", "$PWD/").Replace("/", "\")
        return Test-HashWatchdogStatic -Path $ParentPath -Depth ($Depth + 1)
    }

    return $false
}


# --- PRE-FLIGHT CHECK ---
if ($Strict) {
    Write-Host "Performing Strict Static Analysis..." -ForegroundColor Cyan
    $FailedChecks = @()
    
    # Check Scenes
    foreach ($scene in $TestScenes) {
        $ScriptPath = Get-ScriptPath -FileItem $scene
        if ($ScriptPath) {
            if (-not (Test-HashWatchdogStatic -Path $ScriptPath)) {
                $FailedChecks += $scene.Name
            }
        } else {
            Write-Host "WARNING: Could not resolve script for $($scene.Name)" -ForegroundColor DarkGray
        }
    }
    
    # Check Scripts
    foreach ($script in $TestScripts) {
         if (-not (Test-HashWatchdogStatic -Path $script.FullName)) {
             $FailedChecks += $script.Name
         }
    }
    
    if ($FailedChecks.Count -gt 0) {
        Write-Host "STRICT FAILURE: The following tests are missing 'TestSafeGuard' (Watchdog/LeakDetector):" -ForegroundColor Red
        foreach ($f in $FailedChecks) {
            Write-Host "  - $f" -ForegroundColor Red
        }
        $ValidationFailed = $true
    }
    
    if ($ValidationFailed) {
        Write-Host "Validation Failed. Aborting Run." -ForegroundColor Red
        exit 1
    }
}


# 1. Run Scenes
foreach ($scene in $TestScenes) {
    $RelPath = Resolve-Path $scene.FullName -Relative
    $result = Run-GodotTest -Name $scene.Name -Arguments "--headless `"$RelPath`""
    if ($result -ne 0) { 
        $GlobalExitCode = 1 
        break 
    }
}

# 2. Run Scripts (Only if scenes passed)
if ($GlobalExitCode -eq 0) {
    foreach ($script in $TestScripts) {

        # Check if script is a test runner (extends SceneTree/MainLoop)
        $Content = Get-Content $script.FullName -Raw
        if ($Content -match "extends\s+(SceneTree|MainLoop)") {
            $RelPath = Resolve-Path $script.FullName -Relative
            $result = Run-GodotTest -Name $script.Name -Arguments "--headless -s `"$RelPath`""
            if ($result -ne 0) { 
                $GlobalExitCode = 1 
                break 
            }
        }
    }
}

if ($GlobalExitCode -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "TESTS FAILED" -ForegroundColor Red
}

exit $GlobalExitCode
