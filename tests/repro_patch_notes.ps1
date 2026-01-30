$RawCommits = @(
    # Features
    "feat: Feature 1", "new: Feature 2", "add: Feature 3", "implement: Feature 4",
    # Fixes
    "fix: Fix 1", "bug: Fix 2", "repair: Fix 3", "resolve: Fix 4", "hotfix: Fix 5",
    # Visuals
    "style: Visual 1", "ui: Visual 2", "visual: Visual 3", "art: Visual 4", "shader: Visual 5", "polish: Visual 6",
    # Tech
    "refactor: Tech 1", "perf: Tech 2", "optim: Tech 3", "clean: Tech 4", "test: Tech 5", "ci: Tech 6", "chore: Tech 7",
    # Docs
    "doc: Doc 1", "readme: Doc 2", "comment: Doc 3",
    # Multi-tag
    "feat: Multi 1 fix: Multi 2",
    "ui: Multi 3 optim: Multi 4",
    "doc: Multi 5 bug: Multi 6"
)

$Cats_Features = @()
$Cats_Fixes = @()
$Cats_Visuals = @()
$Cats_Tech = @()
$Cats_Docs = @()
$Cats_Other = @()

foreach ($Commit in $RawCommits) {
    $Matched = $false

    if ($Commit -match "(?i)(^(feat|new|add|implement))|(\s(feat|new|add|implement):)") {
        $Cats_Features += "- $Commit"
        $Matched = $true
    }
    if ($Commit -match "(?i)(^(fix|bug|repair|resolve|hotfix))|(\s(fix|bug|repair|resolve|hotfix):)") {
        $Cats_Fixes += "- $Commit"
        $Matched = $true
    }
    if ($Commit -match "(?i)(^(style|ui|visual|art|shader|polish))|(\s(style|ui|visual|art|shader|polish):)") {
        $Cats_Visuals += "- $Commit"
        $Matched = $true
    }
    if ($Commit -match "(?i)(^(refactor|perf|optim|clean|test|ci|chore))|(\s(refactor|perf|optim|clean|test|ci|chore):)") {
        $Cats_Tech += "- $Commit"
        $Matched = $true
    }
    if ($Commit -match "(?i)(^(doc|readme|comment))|(\s(doc|readme|comment):)") {
        $Cats_Docs += "- $Commit"
        $Matched = $true
    }
    
    if (-not $Matched) {
        $Cats_Other += "- $Commit"
    }
}

Write-Host "--- Results ---"
Write-Host "Features ($($Cats_Features.Count)/5 expected):"
$Cats_Features | ForEach-Object { Write-Host "  $_" }

Write-Host "`nFixes ($($Cats_Fixes.Count)/6 expected):"
$Cats_Fixes | ForEach-Object { Write-Host "  $_" }

Write-Host "`nVisuals ($($Cats_Visuals.Count)/7 expected):"
$Cats_Visuals | ForEach-Object { Write-Host "  $_" }

Write-Host "`nTech ($($Cats_Tech.Count)/8 expected):"
$Cats_Tech | ForEach-Object { Write-Host "  $_" }

Write-Host "`nDocs ($($Cats_Docs.Count)/4 expected):"
$Cats_Docs | ForEach-Object { Write-Host "  $_" }

Write-Host "`nOther ($($Cats_Other.Count)/0 expected):"
$Cats_Other | ForEach-Object { Write-Host "  $_" }

# Verification Logic
$Missed = $false

# Check Multi-tags
if ($Cats_Fixes -notcontains "- feat: Multi 1 fix: Multi 2") {
    Write-Host "`n[FAIL] Multi-tag 'fix' missed in 'feat: Multi 1 fix: Multi 2'" -ForegroundColor Red
    $Missed = $true
}
if ($Cats_Tech -notcontains "- ui: Multi 3 optim: Multi 4") {
    Write-Host "`n[FAIL] Multi-tag 'optim' missed in 'ui: Multi 3 optim: Multi 4'" -ForegroundColor Red
    $Missed = $true
}
if ($Cats_Fixes -notcontains "- doc: Multi 5 bug: Multi 6") {
    Write-Host "`n[FAIL] Multi-tag 'bug' missed in 'doc: Multi 5 bug: Multi 6'" -ForegroundColor Red
    $Missed = $true
}

if (-not $Missed) {
    Write-Host "`n[PASS] All multi-tags correctly categorized!" -ForegroundColor Green
}
