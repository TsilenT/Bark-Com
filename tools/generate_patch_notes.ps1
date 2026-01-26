param (
    [string]$Version
)

$ErrorActionPreference = "Stop"
$PatchNotesDir = "patch_notes"

if (-not (Test-Path $PatchNotesDir)) {
    New-Item -ItemType Directory -Path $PatchNotesDir | Out-Null
}

$HeadHash = git rev-parse HEAD

try {
    $LatestTag = git describe --tags --abbrev=0
} catch {
    $LatestTag = $null
}

$StartRef = $null
$EndRef = $null
$DetectedVersion = "0.0.1"

if ($null -eq $LatestTag) {
    Write-Host "No tags found. Generating notes for all commits." -ForegroundColor Yellow
    $EndRef = "HEAD"
} else {
    $LatestTagHash = git rev-parse $LatestTag

    if ($HeadHash -eq $LatestTagHash) {
        Write-Host "HEAD is currently at tag $LatestTag." -ForegroundColor Cyan
        $EndRef = $LatestTag
        $DetectedVersion = $LatestTag

        try {
            $PreviousTag = git describe --tags --abbrev=0 "$LatestTag^" 2>$null
        } catch {
            $PreviousTag = $null
        }

        if ($PreviousTag) {
            $StartRef = $PreviousTag
        }
    } else {
        Write-Host "HEAD is ahead of tag $LatestTag." -ForegroundColor Cyan
        $StartRef = $LatestTag
        $EndRef = "HEAD"
        $DetectedVersion = "Unreleased" 
    }
}

if ($Version) {
    $DetectedVersion = $Version
}

$SafeVersion = $DetectedVersion -replace '^v','' 

if ($StartRef) {
    $Range = "$StartRef..$EndRef"
} else {
    $Range = $EndRef
}

$RawCommits = git log $Range --pretty=format:"%s"

if (-not $RawCommits) {
    Write-Host "No commits found." -ForegroundColor Yellow
    exit
}

# Define Categories using simple arrays
$Cats_Features = @()
$Cats_Fixes = @()
$Cats_Visuals = @()
$Cats_Tech = @()
$Cats_Docs = @()
$Cats_Other = @()

foreach ($Commit in $RawCommits) {
    if ($Commit -match "(?i)^(feat|new|add|implement)") {
        $Cats_Features += "- $Commit"
    }
    elseif ($Commit -match "(?i)^(fix|bug|repair|resolve|hotfix)") {
        $Cats_Fixes += "- $Commit"
    }
    elseif ($Commit -match "(?i)^(style|ui|visual|art|shader|polish)") {
        $Cats_Visuals += "- $Commit"
    }
    elseif ($Commit -match "(?i)^(refactor|perf|optim|clean|test|ci|chore)") {
        $Cats_Tech += "- $Commit"
    }
    elseif ($Commit -match "(?i)^(doc|readme|comment)") {
        $Cats_Docs += "- $Commit"
    }
    else {
        $Cats_Other += "- $Commit"
    }
}

$E_Rocket = [char]::ConvertFromUtf32(0x1F680)
$E_Bug    = [char]::ConvertFromUtf32(0x1F41B)
$E_Art    = [char]::ConvertFromUtf32(0x1F3A8)
$E_Wrench = [char]::ConvertFromUtf32(0x1F527)
$E_Page   = [char]::ConvertFromUtf32(0x1F4C4)
$E_Memo   = [char]::ConvertFromUtf32(0x1F4DD)

$MDContent = @("# Patch Notes $DetectedVersion", "", "Range: $Range", "")

if ($Cats_Features.Count -gt 0) {
    $MDContent += "## " + $E_Rocket + " Features & Content"
    $MDContent += $Cats_Features
    $MDContent += ""
}
if ($Cats_Fixes.Count -gt 0) {
    $MDContent += "## " + $E_Bug + " Bug Fixes"
    $MDContent += $Cats_Fixes
    $MDContent += ""
}
if ($Cats_Visuals.Count -gt 0) {
    $MDContent += "## " + $E_Art + " Visuals & Polish"
    $MDContent += $Cats_Visuals
    $MDContent += ""
}
if ($Cats_Tech.Count -gt 0) {
    $MDContent += "## " + $E_Wrench + " Tech & Refactor"
    $MDContent += $Cats_Tech
    $MDContent += ""
}
if ($Cats_Docs.Count -gt 0) {
    $MDContent += "## " + $E_Page + " Documentation"
    $MDContent += $Cats_Docs
    $MDContent += ""
}
if ($Cats_Other.Count -gt 0) {
    $MDContent += "## " + $E_Memo + " Other Changes"
    $MDContent += $Cats_Other
    $MDContent += ""
}

$FinalContent = $MDContent -join "`n"

$FileName = "release_${SafeVersion}_patch_notes.md"
$FilePath = Join-Path $PatchNotesDir $FileName

$FinalContent | Out-File -FilePath $FilePath -Encoding UTF8
Write-Host "Patch notes generated: $FilePath" -ForegroundColor Green
