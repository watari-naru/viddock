# VidDock

Chrome side-panel video downloader for supported non-DRM media. The app includes a Windows local helper to produce playable MP4 files. Respect site terms and content rights.

**Latest: VidDock181 (version 1.8.1)**

[Install VidDock (no GitHub login)](./releases/latest) — download and run `VidDockSetup.cmd`. In Chrome, open `chrome://extensions` and load `%LOCALAPPDATA%\VidDock\Extension` once. Existing installations may use the older `%LOCALAPPDATA%\WatariVideoHelper\Extension` folder to preserve settings.

If the helper is not reachable, run `VidDockSetup.cmd` again to repair its Windows startup and Native Messaging registration. Updates are checked and applied manually from the side panel; a public `update.json` and SHA-256 verified release archive are used.

Changes in 1.8.1: automatically retry read-only helper connections once after native restart, route TokyoMotion candidates via helper with page Referer, and report HTTP 403 restrictions accurately. Some site-controlled streams may still reject downloads. No DRM circumvention is provided.

All user settings and private GitHub credentials stay local. No GitHub sign-in required on receiving PCs.
