# VidDock

A Chrome side-panel downloader for supported non-DRM media, with a local Windows helper.

## Install or repair

Download **VidDockSetup.cmd** from the [latest release](https://github.com/watari-naru/viddock/releases/latest). No GitHub login is required. Run setup once, wait for SETUP OK, then reload VidDock at chrome://extensions.

Fresh installs use `%LOCALAPPDATA%\VidDock\Extension`. Existing installations may retain `%LOCALAPPDATA%\WatariVideoHelper\Extension` to preserve settings. Do not delete the installed application directory.

## VidDock192

Windows virtual-environment Python launchers may use a different process ID from the actual worker. The old supervisor could terminate a healthy helper because those IDs differed. VidDock192 verifies a per-launch identifier instead. It also journals download status locally so a restarted helper can report interrupted jobs rather than losing the job ID.

The dependency status now shows the actual yt-dlp version used by the helper. Source HTTP403 errors are distinct from local process failures and depend on the provider. This release does not guarantee that every video or HLS stream can be downloaded, does not automatically resume interrupted bytes, and does not bypass DRM or authorization.

Tests include different launcher/worker processes, survival beyond the old startup timeout, a Windows installed-venv 25-second stability check, job journal recovery, upgrades and rollback. Actual website saving on your PC remains unverified. Re-run the installer once for this release so the previously loaded supervisor is replaced.
