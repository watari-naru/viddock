# VidDock

A Chrome side-panel downloader for supported non-DRM media, with a local Windows helper.

## Install or repair

Download **VidDockSetup.cmd** from the [latest release](https://github.com/watari-naru/viddock/releases/latest). No GitHub login is required. Run setup once, wait for SETUP OK, then reload VidDock at chrome://extensions.

Fresh installs use `%LOCALAPPDATA%\VidDock\Extension`. Existing installations may retain `%LOCALAPPDATA%\WatariVideoHelper\Extension` to preserve settings. Do not delete the installed application directory.

## VidDock 1.9.10 — sleeping tabs and window batch saving

Use **「このウィンドウを再スキャンして一括保存」** to check the current window and reserve one detected video per eligible tab at the best available quality.

- Discarded tabs are restored with at most one reload. Frozen tabs are activated first when **「復帰・検出に必要なタブを一時表示して確認」** is enabled.
- Loaded tabs are scanned without reloading. A reloaded tab's old media URLs and request headers are cleared so the new page can supply fresh information.
- Page loading is checked for up to 30 seconds, then video discovery continues for up to 45 seconds, including delayed players and embedded frames.
- The panel shows every tab's result. Finishing the scan means reservations have been checked; the individual downloads continue in the download list.
- Stopping, closing or navigating a tab, and worker restarts are guarded against duplicate reservations. A request with an uncertain submission result is not sent again automatically.

### Update an existing installation

After active downloads finish, open **「アプリの更新」 → 「↻ 更新を確認」 → 「アップデート」**. The extension reloads after a successful update. If the installed helper cannot update, run the current **VidDockSetup.cmd** from the latest release to repair it.

### Earlier repair in VidDock192

Windows virtual-environment Python launchers may use a different process ID from the actual worker. The old supervisor could terminate a healthy helper because those IDs differed. VidDock192 verifies a per-launch identifier instead. It also journals download status locally so a restarted helper can report interrupted jobs rather than losing the job ID.

The dependency status now shows the actual yt-dlp version used by the helper. Source HTTP403 errors are distinct from local process failures and depend on the provider. This release does not guarantee that every video or HLS stream can be downloaded, does not automatically resume interrupted bytes, and does not bypass DRM or authorization.

Tests include different launcher/worker processes, survival beyond the old startup timeout, a Windows installed-venv 25-second stability check, job journal recovery, upgrades and rollback. Actual website saving on your PC remains unverified. Re-run the installer once for this release so the previously loaded supervisor is replaced.
