# VidDock

VidDock saves supported non-DRM video streams as MP4 using a Chrome side panel and a local Windows helper.

## Download

[VidDockSetup.cmd](./releases/latest) - public installation and repair; GitHub sign-in is not required.

Open chrome://extensions and load the folder shown by the installer once. On a new PC that is usually `%LOCALAPPDATA%\VidDock\Extension`, while existing installations may use `%LOCALAPPDATA%\WatariVideoHelper\Extension`.

## VidDock190

- Carries **Referer**, **Origin**, **User-Agent**, and **Accept-Language** from detected playback requests to the non-DRM downloader when available.
- Keeps sensitive **Cookie** and **Authorization** request headers out of the extension's captured request context and download records.
- Preserves stable video query IDs while removing expiring signature parameters from duplicate identifiers.
- Redacts signed media URLs and credentials from stored error messages.
- Synchronizes Chrome and helper save folders in a consistent order.
- Includes source-upgrade tests, rollback tests, and an actual Windows PowerShell installer smoke test.

This release improves detection and delivery of legitimate playback request context but **cannot guarantee downloads from any particular site**. Site-specific authorization, account access, DRM, and server-side download restrictions are not bypassed.

Sources remain in the owner's private development repository; the public repository contains only installation packages and update metadata.
