# VidDock

VidDock is a Chrome side-panel downloader for supported non-DRM videos. It saves playable MP4 files with a Windows local helper, FFmpeg and yt-dlp.

## Install and repair

No GitHub login is needed. Download **[VidDockSetup.cmd](./releases/latest)** from the latest release and run it.

Chrome requires you to register the installed Extension folder once at `chrome://extensions`. On new PCs it is typically `%LOCALAPPDATA%\VidDock\Extension`. Existing upgraded installations can retain `%LOCALAPPDATA%\WatariVideoHelper\Extension`.

**If VidDock182 update failed with "New helper could not start":** Run the newly published VidDockSetup.cmd once rather than repeatedly clicking Update. The old supervisor is still running and must be repaired. Existing downloads, preferences, and the pairing token are preserved.

## VidDock183

- Captures Python helper startup errors in `helper_startup_failure.log` and provides diagnostics in `supervisor.log`.
- Delays optional curl_cffi installation until the helper is serving health responses.
- Installs just missing curl_cffi rather than upgrading yt-dlp during restart.
- Discards stale Python bytecode before restarting the helper.
- Adds automated published-182-to-183 migration and rollback tests on Windows and Linux.

**Note:** Automated tests do not guarantee that the update will succeed on every local PC. If setup still fails, read `supervisor.log` and `helper_startup_failure.log` from the application directory.

No DRM circumvention, credential extraction, or guarantee of accessing Cloudflare-restricted streams is offered. Respect site terms and content rights.

The development repository stays private; only releases and update metadata are public.
