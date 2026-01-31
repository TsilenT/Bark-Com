$Commit = "refactor: abstract out mission generation and objective/unit spawning fix: loot crates now can spawn any consumable item fix: rebalance enemy spawn potential across levels feat: scaling difficulty"
Write-Host "Original: $Commit"

# Define Keywords
$Feat = "feat|new|add|implement"
$Fix = "fix|bug|repair|resolve|hotfix"
$Vis = "style|ui|visual|art|shader|polish"
$Tech = "refactor|perf|optim|clean|test|ci|chore"
$Doc = "doc|readme|comment"

$AllKeywords = "$Feat|$Fix|$Vis|$Tech|$Doc"

# Logic: Replace " keyword:" with "`nkeyword:" (Note the leading space in match to avoid matching mid-word)
# We match `\s($AllKeywords):`
# We use regex case insensitive (?i)

$SplitPattern = "(?i)\s($AllKeywords):"
$ReplacePattern = "`n`$1:"

$Processed = $Commit -replace $SplitPattern, $ReplacePattern
$Segments = $Processed -split "`n"

Write-Host "--- Segments ---"
foreach ($Seg in $Segments) {
    Write-Host "[$Seg]"
    
    # Simulate Classification
    if ($Seg -match "(?i)^(feat|new|add|implement):") { Write-Host " -> Feature" }
    elseif ($Seg -match "(?i)^(fix|bug|repair|resolve|hotfix):") { Write-Host " -> Fix" }
    elseif ($Seg -match "(?i)^(refactor|perf|optim|clean|test|ci|chore):") { Write-Host " -> Tech" }
    else { Write-Host " -> Other" }
}
