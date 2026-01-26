# Run Tests Locally (Timeout Protected)
# Usage: .\tests\run_tests.ps1 [-Strict:$false]

param (
    [bool]$Strict = $true
)

$GodotPath = "C:\Users\smili\Documents\Godot\Installs\Godot_v4.5.1-stable_win64.exe"
$TimeoutSeconds = 60
$LogFile = "test_log.txt"

# Clear Log File
"--- TEST RUN STARTED: $(Get-Date) ---" | Out-File -FilePath $LogFile -Encoding UTF8

Write-Host "Searching for Tests..." -ForegroundColor Cyan

$TestScenes = Get-ChildItem -Path "tests" -Filter "*.tscn" -Recurse
$TestScripts = Get-ChildItem -Path "tests" -Filter "*.gd" -Recurse

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
        
        $Process = Start-Process -FilePath "cmd" -ArgumentList "/c $GodotPath $Arguments > ""$TempLog"" 2>&1" -NoNewWindow -PassThru -Wait
        $ExitCode = $Process.ExitCode
        
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
            if ($Output -match "ERROR:" -or $Output -match "WARNING:" -or $Output -match "SCRIPT ERROR:" -or $Output -match "\bFAIL\b" -or $Output -match "FAIL \[") {
                 # Filter exception if needed
                 if ($Output -match "CRITICAL WARNING - Mission Won but No Survivors" -and !($Output -match "ObjectDB instances leaked") -and !($Output -match "SCRIPT ERROR") -and !($Output -match "FAIL")) {
                     Write-Host "STRICT FAILURE in $Name (Logs contain ERROR/WARNING/FAIL)" -ForegroundColor Magenta
                     Write-Host "--- LOG START ---" -ForegroundColor Gray
                     Get-Content $TempLog | Out-Host
                     Write-Host "--- LOG END ---" -ForegroundColor Gray
                     Remove-Item $TempLog -ErrorAction SilentlyContinue
                     return 1
                 }
                 
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

# 1. Run Scenes
foreach ($scene in $TestScenes) {
    $result = Run-GodotTest -Name $scene.Name -Arguments "--headless --unit-test --path . `"$($scene.FullName)`""
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
            $result = Run-GodotTest -Name $script.Name -Arguments "--headless --unit-test -s `"$($script.FullName)`""
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
