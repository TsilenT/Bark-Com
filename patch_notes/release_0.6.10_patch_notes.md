# Patch Notes 0.6.10

## 🚀 Features & Content
- **Final Mission Overhaul**: Implemented 10-wave survival mode with progressive difficulty.
- **Golden Hydrant Defense**: Added "Sacred Artifact" defense objective. Hydrant has 100 HP and must survive 30 turns.
- **Boss Upgrades**:
    - Added `EldritchHowlAbility` (AoE Panic/Debuff).
    - Added `TentacleLashAbility` (Mid-range Pull).
    - Increased Boss HP to 70 and Armor to 1.
- **Elite Enemies**: Added `Whisperer` and `Infiltrator` to procedural spawn pools.

## 🧠 AI Improvements
- **Boss Aggression**: Tuned `DogthulhuBehavior` to prioritize closing gaps and using abilities over passive shooting.
- **Target Prioritization**: Enemies now prefer attacking Players over Objectives (allowing "Tanking" strategies).
- **Breakout Logic**: Enemies stuck behind cover will now attack the cover to create paths.
- **Rusher AI**: Enabled `GoForAnkles` ability usage for Rusher archetypes.

## 🐛 Bug Fixes
- **fix**: Golden Hydrant no longer instantly dies to Acid Hazards (Fixed double-damage bug + enforced 100 HP).
- **fix**: CI/CD Pipeline failure resolved (PowerShell `IsLinux` variable conflict).
- **fix**: Fixed `Whisperer` crash due to missing `get_ai_score` in abilities.
- **fix**: Resolved Global Test Timeout by enforcing `TestSafeGuard` across all tests.
- **fix**: Corrected Enemy Accuracy logic (Archetype-specific values).

## 🔧 Tech & Refactor
- **Test Runner**: Enhanced `run_tests_parallel.ps1` with detailed timing summaries and per-worker performance metrics.
- **Strict Mode**: Enforced strict test safeguards to protect user save data during automated runs.
- **Docs**: Added `docs/dev_guide/spawning_rules.md` for wave generation documentation.
