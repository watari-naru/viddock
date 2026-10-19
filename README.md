# VidDock

A Chrome side-panel downloader for supported non-DRM video. It uses a local Windows helper and FFmpeg to save playable MP4 files.

## Install and repair

**Download VidDockSetup.cmd from the [latest release](../../releases/latest).** No GitHub login required. Open `chrome://extensions` and reload VidDock after setup.

For fresh installs the extension is typically at `%LOCALAPPDATA%\VidDock\Extension`. Existing installations can retain `%LOCALAPPDATA%\WatariVideoHelper\Extension`.

**VidDock191 repair note:** If VidDock190 shows `New helper could not start (exit=0)` followed by `Previous version restored`, run **VidDockSetup.cmd once** instead of repeatedly pressing Update. This restarts the existing Windows supervisor, which otherwise remains loaded with the old restart-checking code. Saved videos, connection token, and settings stay in the application directory.

## VidDock191

- Fixes false update rollbacks caused by the initial helper's health check racing with an update request.
- The newly started helper ignores restart markers requesting its current or an older version.
- The supervisor validates its exact child PID and retries at most twice after an unexpected clean exit; persistent failures still roll back safely.
- Tested with real local helper processes on Windows and Linux, including VidDock190 to VidDock191 upgrades, stale restart markers, deliberate startup errors and rollback.

A successful local automated test does not guarantee any particular website allows video saving. Some 403 responses are enforced by the video provider. The application does not decrypt DRM or bypass authorization requirements.

The GitHub source repository remains private; public release files and update metadata contain no account tokens.
