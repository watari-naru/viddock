@echo off
setlocal
title VidDockSetup
echo VidDockSetup
echo Installing VidDock from public GitHub. No GitHub login is required.
set "VIDDOCK_URL=https://raw.githubusercontent.com/watari-naru/viddock/main/installer.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $p=Join-Path $env:TEMP ('VidDockInstaller'+[guid]::NewGuid().ToString('N')+'.ps1'); try { Invoke-WebRequest -UseBasicParsing -Uri '%VIDDOCK_URL%' -OutFile $p; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p; if($LASTEXITCODE -ne 0){throw ('Installer returned '+$LASTEXITCODE)} } finally { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }"
if errorlevel 1 (
  echo VidDock setup failed. Existing installation is preserved whenever possible.
) else (
  echo VidDock setup completed. Load the Extension folder printed above in chrome://extensions.
)
pause
