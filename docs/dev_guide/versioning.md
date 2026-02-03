# Versioning Documentation

## Overview
Bark-Com uses an automated versioning system based on Git tags. This ensures that the version displayed in-game matches the specific commit or release state of the codebase.

## How it Works
1.  **Git Tagging**: Semantic versions (e.g., `v0.9.0`) are created using `git tag`.
2.  **Generation Script**: The `generate_version.ps1` script runs `git describe --tags --always --dirty` to extract the full version string (including commit hash and dirty state if applicable).
3.  **Godot Integration**: The script generates a file at `scripts/core/Version.gd` containing a `const BUILD_VERSION` string.
4.  **UI Display**: The `BaseScene.gd` (Main Menu/Hub) reads this constant and displays it in the bottom-right corner.

## Usage
### Generating the Version File
Run the following PowerShell command in the project root:
```powershell
.\generate_version.ps1
```
This is required before exporting the game to ensure the correct version is baked in.

### Accessing Version in Code
The version is available globally via the `Version` class (if generated):
```gdscript
if ClassDB.class_exists("Version"):
    print("Current Version: " + Version.BUILD_VERSION)
```
*Note: Since `Version.gd` is a generated file, always assume it might be missing in a fresh dev environment until the script is run.*

## CI/CD Integration
The versioning process is automated in the GitHub Actions pipeline (`.github/workflows/ci_cd_pipeline.yml`).
-   The `build` job runs `generate_version.ps1` before exporting the project.
-   This ensures that every build artifact (Windows/Web) contains the correct git tag or commit hash.

## Troubleshooting
-   **"v0.0.0-dev"**: This fallback version appears if `git` is not installed or the script fails.
-   **File Missing**: Run `.\generate_version.ps1` to restore `Version.gd`.
