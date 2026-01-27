param ()

$ErrorActionPreference = "Stop"
$GodotFilesPattern = "\.(gd|tscn|tres|import|json|cfg)$|project\.godot|tests/"
$CoreFilesPattern = "^(scripts/core/|scripts/managers/GameManager.gd|project.godot|tests/run_tests.ps1|scripts/Global.gd)" # Add meaningful core patterns here

# 1. Get Staged Files
echo "Checking staged files..."
$StagedFiles = git diff --cached --name-only

if (-not $StagedFiles) {
    Write-Host "No staged files. Skipping tests." -ForegroundColor Green
    exit 0
}

# 2. Filter for Game Logic
$GameFiles = $StagedFiles | Where-Object { $_ -match $GodotFilesPattern }

if (-not $GameFiles) {
    Write-Host "No game logic changes detected. Skipping Tests." -ForegroundColor Green
    exit 0
}

# 3. Analyze for Targets
$Targets = @()
$RunAll = $false

foreach ($File in $GameFiles) {
    # If core file changed, run everything
    if ($File -match $CoreFilesPattern) {
        Write-Host "Core file changed ($File). Running ALL tests." -ForegroundColor Yellow
        $RunAll = $true
        break
    }

    # If test file changed, run it directly
    if ($File -match "^tests/") {
        $Targets += $File
        continue
    }

    # If feature file changed, try to find related tests
    # Strategy 1: Search for tests referencing the class name (or filename base)
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File)
    
    # Simple Heuristic: If BaseName is "EnemyUnit", search tests for "EnemyUnit"
    # Limitation: might match too many things if common word
    if ($BaseName.Length -gt 3) {
        # Find tests that contain this string (Dependency Search)
        # Note: This is a bit slow if many files, but faster than running full suite
        $DependentTests = Select-String -Path "tests/*.gd" -Pattern $BaseName -List | Select-Object -ExpandProperty Path
        if ($DependentTests) {
            $Targets += $DependentTests
        }
        
        # Strategy 2: Match filename pattern (e.g. MissionManager -> test_mission_rewards.gd)
        # Split CamelCase? "MissionManager" -> "Mission"
        if ($BaseName -match "^([A-Z][a-z]+)") {
            $Prefix = $matches[1]
            if ($Prefix.Length -gt 3) {
                 # Add prefix as a target pattern for run_tests.ps1 to resolve
                 $Targets += $Prefix
            }
        }
    }
}

$Targets = $Targets | Select-Object -Unique

# 4. Execute Tests
if ($RunAll -or ($Targets.Count -eq 0)) {
    if (-not $RunAll) { Write-Host "No specific tests found for changes. Running Full Suite." -ForegroundColor Cyan }
    
    # Run all tests
    & ".\tests\run_tests.ps1"
    exit $LASTEXITCODE
} else {
    Write-Host "Running Targeted Tests: $($Targets -join ', ')" -ForegroundColor Cyan
    
    # Pass targets to runner
    & ".\tests\run_tests.ps1" -Targets $Targets
    exit $LASTEXITCODE
}
