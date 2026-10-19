# Windows PowerShell 5.1+. ASCII source; no global execution-policy changes.
[CmdletBinding()]
param([string]$PackagePath='', [string]$InstallRoot='', [switch]$SkipDependencies, [switch]$NoOpen)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$repo='watari-naru/viddock'
$expectedId='fkdjednhijimbbelplimgojldphcoaij'
if (-not $InstallRoot) {
  # Preserve an existing extension directory and browser identity during migration.
  $legacy=Join-Path $env:LOCALAPPDATA 'WatariVideoHelper'
  $legacyManifest=Join-Path $legacy 'Extension\manifest.json'
  $InstallRoot=Join-Path $env:LOCALAPPDATA 'VidDock'
  if (Test-Path -LiteralPath $legacyManifest) {
    try {
      $oldManifest=Get-Content -LiteralPath $legacyManifest -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($oldManifest.name -in @('Watari Video Helper','VidDock')) { $InstallRoot=$legacy }
    } catch {}
  }
}
$root=[IO.Path]::GetFullPath($InstallRoot)
$extension=Join-Path $root 'Extension'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('WatariSetup-'+[guid]::NewGuid().ToString('N'))
$backup=Join-Path $root ('setup-backup-'+[guid]::NewGuid().ToString('N'))
$changed=$false
$utf8=New-Object Text.UTF8Encoding($false)
function Write-Text([string]$Path,[string]$Value) { [IO.File]::WriteAllText($Path,$Value,$utf8) }
function Refresh-Path { $env:Path=$env:Path+';'+[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User') }
function Download-Verified([string]$Url,[string]$ChecksumUrl,[string]$Path) {
  Write-Host ('Downloading '+$Url) -ForegroundColor Cyan
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Path
  $sum=Invoke-WebRequest -UseBasicParsing -Uri $ChecksumUrl
  $value=$sum.Content
  if ($value -is [byte[]]) { $value=[Text.Encoding]::UTF8.GetString($value) }
  $expected=([regex]::Match([string]$value,'(?i)[0-9a-f]{64}')).Value.ToLowerInvariant()
  if (-not $expected -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Downloaded archive failed SHA256 verification.'
  }
}
function Install-FFmpegPortable {
  $target=Join-Path $root 'Tools\FFmpeg'
  $result=Join-Path $target 'ffmpeg.exe'
  if ((Test-Path -LiteralPath $result) -and (Test-Path -LiteralPath (Join-Path $target 'ffprobe.exe'))) {return $result}
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  $zipFile=Join-Path $temp 'ffmpeg.zip'
  $url='https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
  Download-Verified $url ($url+'.sha256') $zipFile
  $out=Join-Path $temp 'ffmpeg-expanded'
  [IO.Compression.ZipFile]::ExtractToDirectory($zipFile,$out)
  foreach ($name in @('ffmpeg.exe','ffprobe.exe')) {
    $binary=Get-ChildItem -LiteralPath $out -File -Filter $name -Recurse | Select-Object -First 1
    if (-not $binary) {throw ('Missing '+$name+' in FFmpeg ZIP.')}
    Copy-Item -LiteralPath $binary.FullName -Destination (Join-Path $target $name) -Force
  }
  return $result
}
function Install-DenoPortable {
  $target=Join-Path $root 'Tools\Deno'
  $binaryPath=Join-Path $target 'deno.exe'
  if (Test-Path -LiteralPath $binaryPath) {return $binaryPath}
  $arch=$env:PROCESSOR_ARCHITECTURE
  if ($arch -eq 'ARM64') {$assetName='deno-aarch64-pc-windows-msvc.zip'}
  elseif ($arch -eq 'AMD64') {$assetName='deno-x86_64-pc-windows-msvc.zip'}
  else {throw 'Deno portable setup requires Windows x64 or ARM64.'}
  $release=Invoke-RestMethod 'https://api.github.com/repos/denoland/deno/releases/latest' -Headers @{'User-Agent'='Watari-Video-Helper'}
  $asset=@($release.assets | Where-Object {$_.name -eq $assetName}) | Select-Object -First 1
  if (-not $asset) {throw 'Official Deno ZIP is unavailable.'}
  $path=Join-Path $temp 'deno.zip'
  Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $path
  if ($asset.digest -and $asset.digest -match '^sha256:([a-fA-F0-9]{64})$') {
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Matches[1].ToLowerInvariant()) {throw 'Deno download checksum mismatch.'}
  }
  $out=Join-Path $temp 'deno-expanded'
  [IO.Compression.ZipFile]::ExtractToDirectory($path,$out)
  $binary=Get-ChildItem -LiteralPath $out -File -Filter deno.exe -Recurse | Select-Object -First 1
  if (-not $binary) {throw 'Missing deno.exe in official ZIP.'}
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  Copy-Item -LiteralPath $binary.FullName -Destination $binaryPath -Force
  return $binaryPath
}
function Install-PythonUser {
  $target=Join-Path $root 'Tools\Python312'
  $binary=Join-Path $target 'python.exe'
  if (Test-Path -LiteralPath $binary) {return $binary}
  if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $suffix='-arm64' }
  elseif ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {$suffix='-amd64'}
  else {throw 'Python user installation requires Windows x64 or ARM64.'}
  $file=Join-Path $temp 'python-3.12.10.exe'
  Invoke-WebRequest -UseBasicParsing -Uri ('https://www.python.org/ftp/python/3.12.10/python-3.12.10'+$suffix+'.exe') -OutFile $file
  $signature=Get-AuthenticodeSignature -LiteralPath $file
  if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Python Software Foundation') {
    throw 'Python installer signature is missing or invalid.'
  }
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  $args=@('/quiet','InstallAllUsers=0','Include_launcher=0','Include_test=0','Include_tcltk=0','Include_doc=0','PrependPath=0',('TargetDir="'+$target+'"'))
  $process=Start-Process -FilePath $file -ArgumentList $args -PassThru -Wait
  if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $binary)) {
    throw ('Python user installation failed (exit code '+$process.ExitCode+').')
  }
  return $binary
}
function Ensure-Tool([string]$Name,[string]$Package) {
  Refresh-Path
  $found=Get-Command $Name -ErrorAction SilentlyContinue
  if ($found) { return $found.Source }
  $portable=@{
    'gh.exe'=(Join-Path $root 'Tools\GitHubCLI\gh.exe')
    'ffmpeg.exe'=(Join-Path $root 'Tools\FFmpeg\ffmpeg.exe')
    'ffprobe.exe'=(Join-Path $root 'Tools\FFmpeg\ffprobe.exe')
    'deno.exe'=(Join-Path $root 'Tools\Deno\deno.exe')
    'py.exe'=(Join-Path $root 'Tools\Python312\python.exe')
  }
  if ($portable.ContainsKey($Name) -and (Test-Path -LiteralPath $portable[$Name])) {return $portable[$Name]}
  if ($SkipDependencies) {return $null}
  $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
  if ($winget) {
    Write-Host ('Trying Windows package installation for '+$Package+'...') -ForegroundColor Cyan
    try {
      & $winget.Source install --id $Package -e --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity | Out-Host
      Refresh-Path
      $found=Get-Command $Name -ErrorAction SilentlyContinue
      if ($found) {return $found.Source}
    } catch {Write-Host ('winget unavailable for '+$Name+'. Switching to direct download.') -ForegroundColor Yellow}
  }
  switch ($Name) {
    'gh.exe' {throw 'GitHub CLI is missing. Re-run the latest VidDockSetup.cmd to install the portable version.'}
    'py.exe' {return (Install-PythonUser)}
    'ffmpeg.exe' {return (Install-FFmpegPortable)}
    'ffprobe.exe' { $null=Install-FFmpegPortable; return (Join-Path $root 'Tools\FFmpeg\ffprobe.exe') }
    'deno.exe' {return (Install-DenoPortable)}
  }
  throw ('No supported installation method for '+$Name)
}
function Get-PublicBytes([string]$Path) {
  if ($Path -notmatch '^(update\.json|releases/VidDock[0-9]+\.zip)$') {throw 'Unexpected update file requested'}
  $url='https://raw.githubusercontent.com/watari-naru/viddock/main/'+$Path
  $output=Join-Path $temp ('public-'+[guid]::NewGuid().ToString('N'))
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $output
    $size=(Get-Item -LiteralPath $output).Length
    if ($size -gt 800000 -or $size -eq 0) {throw 'Public release file exceeds size limit'}
    return ,([IO.File]::ReadAllBytes($output))
  } finally { Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue }
}
function Stop-Watari {
  $processes=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -in @('python.exe','pythonw.exe') -and $_.CommandLine -and $_.CommandLine.IndexOf($root,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.CommandLine -match '(runner|youtube_helper)\.py'
  })
  $processes | Sort-Object @{Expression={if ($_.CommandLine -match 'runner\.py') {0} else {1}}} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 500
}
try {
  New-Item -ItemType Directory -Path $temp,$root -Force | Out-Null
  Write-Host '[1/6] Checking tools and GitHub authentication...' -ForegroundColor Cyan
  if (-not $PackagePath) {
    $meta=$utf8.GetString((Get-PublicBytes 'update.json')) | ConvertFrom-Json
    if ($meta.repo -ne $repo -or $meta.version -notmatch '^\d+\.\d+\.\d+$' -or $meta.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid public release metadata.' }
    if ($meta.asset -ne ('releases/VidDock'+$meta.version.Replace('.','')+'.zip')) { throw 'Invalid release ZIP name.' }
    $PackagePath=Join-Path $temp 'release.zip'
    [IO.File]::WriteAllBytes($PackagePath,(Get-PublicBytes $meta.asset))
    if ((Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $meta.sha256) {throw 'SHA256 mismatch. Nothing was installed.'}
  }
  $pyCommand=Get-Command py.exe -ErrorAction SilentlyContinue
  $python=$null
  if ($pyCommand) { $python=(& $pyCommand.Source -3 -c 'import sys; print(sys.executable)' 2>$null | Select-Object -First 1) }
  if (-not $python -or -not (Test-Path -LiteralPath $python)) {
    $candidate=Get-Command python.exe -ErrorAction SilentlyContinue
    if ($candidate) { $python=(& $candidate.Source -c 'import sys; print(sys.executable)' 2>$null | Select-Object -First 1) }
  }
  if (-not $python -or -not (Test-Path -LiteralPath $python)) {
    $newPython=Ensure-Tool 'py.exe' 'Python.Python.3.12'
    if ($newPython -and [IO.Path]::GetFileName($newPython).ToLowerInvariant() -eq 'python.exe') {
      $python=$newPython
    } elseif ($newPython) {
      $python=(& $newPython -3 -c 'import sys; print(sys.executable)' | Select-Object -First 1)
    }
  }
  if (-not $python -or -not (Test-Path -LiteralPath $python)) { throw 'Python 3 was not found.' }
  & $python -c 'import sys; assert sys.version_info >= (3,10)'
  if ($LASTEXITCODE -ne 0) { throw 'Python 3.10 or newer is required.' }
  Write-Host '[2/6] Validating package...' -ForegroundColor Cyan
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=[IO.Compression.ZipFile]::OpenRead($PackagePath)
  try {
    $seen=@{}; $total=0
    if ($zip.Entries.Count -gt 150) { throw 'Too many archive entries.' }
    foreach ($entry in $zip.Entries) {
      if (-not $entry.Name) { continue }
      $name=$entry.FullName
      if ($name -notmatch '^watari_video_helper/[A-Za-z0-9_./-]+$' -or $name.Contains('..') -or $name.Contains('\') -or $seen.ContainsKey($name.ToLowerInvariant())) { throw 'Unsafe archive path.' }
      $seen[$name.ToLowerInvariant()]=$true; $total+=$entry.Length
      if ($total -gt 8388608 -or $entry.Length -gt 2097152) { throw 'Archive expansion limit exceeded.' }
    }
  } finally { $zip.Dispose() }
  [IO.Compression.ZipFile]::ExtractToDirectory($PackagePath,(Join-Path $temp 'stage'))
  $source=Join-Path $temp 'stage\watari_video_helper'
  $manifest=Get-Content -LiteralPath (Join-Path $source 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.name -ne 'VidDock' -or $manifest.manifest_version -ne 3) { throw 'Wrong extension package.' }
  if ($meta -and $manifest.version -ne $meta.version) { throw 'Package version mismatch.' }
  $hash=[Security.Cryptography.SHA256]::Create()
  try { $digest=$hash.ComputeHash([Convert]::FromBase64String($manifest.key)) } finally { $hash.Dispose() }
  $id=-join ($digest[0..15] | ForEach-Object { [char](97+($_ -shr 4)); [char](97+($_ -band 15)) })
  if ($id -ne $expectedId) { throw 'Extension identity mismatch.' }
  & $python -m compileall -q (Join-Path $source 'helper')
  if ($LASTEXITCODE -ne 0) { throw 'Python source validation failed.' }
  Get-ChildItem -LiteralPath $source -Filter __pycache__ -Directory -Recurse | Remove-Item -Recurse -Force
  Write-Host '[3/6] Preparing isolated video runtime...' -ForegroundColor Cyan
  $runtime=Join-Path $root 'Runtime'
  $runtimePython=Join-Path $runtime 'Scripts\python.exe'
  if (-not (Test-Path -LiteralPath $runtimePython)) {
    & $python -m venv $runtime
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create isolated Python runtime.' }
  }
  if (-not $SkipDependencies) {
    & $runtimePython -m pip install --disable-pip-version-check --upgrade 'yt-dlp[default]'
    if ($LASTEXITCODE -ne 0) { throw 'yt-dlp installation failed.' }
  }
  $ffmpeg=Ensure-Tool 'ffmpeg.exe' 'Gyan.FFmpeg'
  $ffprobe=Ensure-Tool 'ffprobe.exe' 'Gyan.FFmpeg'
  $deno=Ensure-Tool 'deno.exe' 'DenoLand.Deno'
  Write-Host '[4/6] Installing to permanent application folder...' -ForegroundColor Cyan
  $keyFile=Join-Path $root '.pairing_key'
  if (Test-Path -LiteralPath $keyFile) {
    $key=(Get-Content -LiteralPath $keyFile -Raw).Trim()
    try {
      $old=Invoke-RestMethod -Uri 'http://127.0.0.1:18763/api/status' -Headers @{'X-Watari-Token'=$key} -TimeoutSec 2
      if ($old.activeDownloads -gt 0) { throw 'Downloads are active. Wait for completion, then rerun setup.' }
    } catch { if ($_.Exception.Message -like 'Downloads are active*') { throw } }
  }
  Stop-Watari
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  if (Test-Path -LiteralPath $extension) { Move-Item -LiteralPath $extension -Destination (Join-Path $backup 'Extension') }
  Get-ChildItem -LiteralPath $root -Filter *.py | Copy-Item -Destination $backup
  foreach ($name in @('extension_path.txt','tools.json','native_host.cmd','com.watari.video_helper.json')) {
    $oldFile=Join-Path $root $name
    if (Test-Path -LiteralPath $oldFile) { Copy-Item -LiteralPath $oldFile -Destination $backup }
  }
  $oldRun=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
  if ($oldRun) { try { $oldRunValue=$oldRun.GetValue('WatariVideoHelper'); $oldVidDockRunValue=$oldRun.GetValue('VidDock') } finally { $oldRun.Dispose() } }
  $changed=$true
  Copy-Item -LiteralPath $source -Destination $extension -Recurse
  # Python helper is installed at the application root, never inside Chrome's extension.
  $helperSource=Join-Path $extension 'helper'
  Get-ChildItem -LiteralPath $helperSource -File -Filter *.py | Copy-Item -Destination $root -Force
  Remove-Item -LiteralPath $helperSource -Recurse -Force
  # Python creates __pycache__; Chrome rejects any directory whose name starts with '_'.
  Get-ChildItem -LiteralPath $extension -Filter '__pycache__' -Directory -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Stop
  if (-not (Test-Path -LiteralPath (Join-Path $extension 'manifest.json'))) {throw 'Chrome extension manifest is missing.'}
  Write-Text (Join-Path $root 'extension_path.txt') $extension
  Write-Text (Join-Path $root 'tools.json') (@{ffmpeg=$ffmpeg;ffprobe=$ffprobe;deno=$deno} | ConvertTo-Json)
  if (-not (Test-Path -LiteralPath $keyFile)) {
    $bytes=New-Object byte[] 24; $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    Write-Text $keyFile (([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant())
  }
  foreach ($file in @('restart.request','update_transaction.json')) {
    $filePath=Join-Path $root $file
    if (Test-Path -LiteralPath $filePath) { Move-Item -LiteralPath $filePath -Destination $backup -Force }
  }
  Write-Text (Join-Path $root 'update_status.json') '{"state":"idle"}'
  Write-Host '[5/6] Registering automatic connection and startup...' -ForegroundColor Cyan
  $nativeCmd=Join-Path $root 'native_host.cmd'
  [IO.File]::WriteAllText($nativeCmd,"@echo off`r`n`"%~dp0Runtime\Scripts\python.exe`" `"%~dp0native_host.py`" %*`r`n",[Text.Encoding]::ASCII)
  $nativeManifest=Join-Path $root 'com.watari.video_helper.json'
  Write-Text $nativeManifest (@{name='com.watari.video_helper';description='VidDock';path=$nativeCmd;type='stdio';allowed_origins=@('chrome-extension://'+$expectedId+'/')} | ConvertTo-Json)
  $reg=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Google\Chrome\NativeMessagingHosts\com.watari.video_helper')
  try { $reg.SetValue('',$nativeManifest) } finally { $reg.Dispose() }
  $pythonw=Join-Path $runtime 'Scripts\pythonw.exe'
  $command='"'+$pythonw+'" "'+(Join-Path $root 'runner.py')+'"'
  $run=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
  try { $run.SetValue('VidDock',$command); $run.DeleteValue('WatariVideoHelper',$false) } finally { $run.Dispose() }
  Start-Process -FilePath $pythonw -ArgumentList ('"'+(Join-Path $root 'runner.py')+'"') -WorkingDirectory $root -WindowStyle Hidden
  Write-Host '[6/6] Verifying running helper...' -ForegroundColor Cyan
  $key=(Get-Content -LiteralPath $keyFile -Raw).Trim(); $health=$null
  for ($i=0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 400
    try {
      $candidate=Invoke-RestMethod -Uri 'http://127.0.0.1:18763/api/status' -Headers @{'X-Watari-Token'=$key} -TimeoutSec 2
      if ($candidate.ok -and $candidate.version -eq $manifest.version) { $health=$candidate; break }
    } catch { }
  }
  if (-not $health) { throw 'Helper startup failed. Check supervisor.log and helper.log in the application folder.' }
  if (-not $SkipDependencies -and (-not $health.ytdlp -or -not $health.ffmpeg)) { throw 'Video tools did not pass the health check.' }
  $changed=$false
  Write-Host ('SETUP OK / helper v'+$health.version+' / automatic connection ready') -ForegroundColor Green
  Write-Host 'Open chrome://extensions, disable the OLD Watari extension, and Load unpacked from:' -ForegroundColor Cyan
  Write-Host $extension -ForegroundColor Yellow
  Write-Host 'After it works, delete the downloaded installer and ZIP if desired. DO NOT delete the application folder above.'
  Write-Host 'Helper history, pairing key and save folder were kept. Browser-only settings in the old extension are not migrated.'
  if (-not $NoOpen) { Set-Clipboard -Value $extension -ErrorAction SilentlyContinue; Start-Process explorer.exe -ArgumentList ('"'+$extension+'"') }
} catch {
  Write-Host ('SETUP FAILED: '+$_.Exception.Message) -ForegroundColor Red
  if ($changed) {
    Stop-Watari
    if (Test-Path -LiteralPath (Join-Path $backup 'Extension')) {
      if (Test-Path -LiteralPath $extension) { Remove-Item -LiteralPath $extension -Recurse -Force }
      Move-Item -LiteralPath (Join-Path $backup 'Extension') -Destination $extension
    }
    Get-ChildItem -LiteralPath $backup -Filter *.py | Copy-Item -Destination $root -Force
    foreach ($name in @('extension_path.txt','tools.json','native_host.cmd','com.watari.video_helper.json')) {
      $oldFile=Join-Path $backup $name
      if (Test-Path -LiteralPath $oldFile) { Copy-Item -LiteralPath $oldFile -Destination $root -Force }
    }
    $reg=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
    try {
      if ($oldRunValue) {$reg.SetValue('WatariVideoHelper',$oldRunValue)}
      if ($oldVidDockRunValue) {$reg.SetValue('VidDock',$oldVidDockRunValue)}
      else {$reg.DeleteValue('VidDock',$false)}
    } finally {$reg.Dispose()}
    Write-Host ('Previous files restored. Backup: '+$backup)
  }
  exit 1
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
