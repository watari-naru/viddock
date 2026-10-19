# VidDock

VidDock is a Chrome side-panel downloader for supported non-DRM videos. It saves playable MP4 files with a Windows local helper, FFmpeg and yt-dlp.

## Install

No GitHub login is needed. Download **VidDockSetup.cmd** from the [latest release](../../releases/latest) and run it.

Load the extension folder shown by the installer in Chrome via `chrome://extensions`. On new PCs the default is `%LOCALAPPDATA%\VidDock\Extension`, while migrated installations can retain `%LOCALAPPDATA%\WatariVideoHelper\Extension`.

After installation, use the VidDock side panel's **Update** controls to update. The original installer can be deleted. Do not delete the installed application directory.

## VidDock182

- Adds the official yt-dlp optional extra `curl_cffi`, installed with `yt-dlp[default,curl-cffi]`.
- When yt-dlp reports a Cloudflare anti-bot challenge during a generic video extraction, VidDock retries **once** using yt-dlp's `--extractor-args generic:impersonate`.
- Existing installations can install the missing optional dependency in the background on first startup after updating.
- The helper status indicates whether browser impersonation is available or still being installed.
- Regular HTTP 403 errors are **not** automatically retried. Site-controlled access restrictions can still block downloads.

No DRM decryption, access-control credential extraction or guaranteed Cloudflare bypass is provided. Respect each website's terms and copyright.

GitHub source repository remains private, while only distribution files and update metadata are public.
