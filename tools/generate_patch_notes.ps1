param (
    [string]$Version,
    [string]$ManualRange
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
        # Ensure we get the commit hash, handling annotated tags correctly
        $LatestTagHash = git rev-parse "$LatestTag^{commit}" 2>$null
        if (-not $LatestTagHash) {
            $LatestTagHash = git rev-parse $LatestTag
        }

        if ($HeadHash -eq $LatestTagHash) {
            Write-Host "HEAD is currently at tag $LatestTag." -ForegroundColor Cyan
            $EndRef = $LatestTag
            $DetectedVersion = $LatestTag

            try {
                # Find the tag immediately preceding the latest one
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

if ($ManualRange) {
    $Range = $ManualRange
} elseif ($StartRef) {
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

# Define Keywords for Splitting
$Feat = "feat|new|add|implement"
$Fix = "fix|bug|repair|resolve|hotfix"
$Vis = "style|ui|visual|art|shader|polish"
$Tech = "refactor|perf|optim|clean|test|ci|chore"
$Doc = "doc|readme|comment"

$AllKeywords = "$Feat|$Fix|$Vis|$Tech|$Doc"
$SplitPattern = "(?i)\s($AllKeywords):"
$ReplacePattern = "`n`$1:"

foreach ($RawCommit in $RawCommits) {
    # Split composite commits (e.g. "feat: A fix: B") into multiple lines
    $Processed = $RawCommit -replace $SplitPattern, $ReplacePattern
    $Segments = $Processed -split "`n"

    foreach ($Commit in $Segments) {
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
