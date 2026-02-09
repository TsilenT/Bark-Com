$env:APPDATA = "C:\Users\smili\AppData\Local\Temp\BarkTestEnv"
$GodotPath = "C:\Users\smili\Documents\Godot\Installs\Godot_v4.5.1-stable_win64.exe"
& $GodotPath --headless -s tests/check_user_dir.gd | Out-File -FilePath "checks_log.txt" -Encoding UTF8
