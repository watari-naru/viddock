"""Reconstruct the exact tested release with explicit, hash-checked line edits."""
from pathlib import Path
import hashlib,io,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE_SHA='363124ce3463989885d9cf3ba11afb0ac05a178171bae790d012a30e22e4fc20'
FINAL_SHA='54b022157ee50c8f95ea731eaca286f32045fe331eba406eb34f3a21a80c6fc9'
CHANGES={
'README.md':('bc7337fcaadd60420f686b37941dd85e86fb3092dbbc46a69c3aa6b99b18dbcd','f9853534bdcf7ed5236ba6a839603891767a89a9e1a80055000647c2a1363e25',[(62,62,'''
## VidDock192

Download jobs now have a local status journal. If the helper restarts, a queued or running job is shown as interrupted at its last saved progress instead of disappearing. Runtime exit logs are kept for troubleshooting. Please check the destination folder before retrying a failed transfer.
''')]),
'RELEASE_NOTES.txt':('fb15e8f37d9bac5378ea94f6712e37648029be82c105e9907ee6ec3af6357fc8','f99eaa802de8449c0318307bd89a63197c1c8346fd94c6c2020cee12489d06ee',[(0,6,'''VidDock192
Persist job state across helper process restarts. Recover interrupted jobs with last known progress and display a clear retry message. Capture runtime exit diagnostics.
''')]),
'helper/runner.py':('5d4feb155cea80339381d65a813a41209f4513b041d7ccac786de3293a73d037','553f6c9c3a7bc8bcd37bee224f0136756d343d75d04a619ff6ae064b16c5ac82',[
(5,5,'import secrets\nimport hmac\n'),
(51,51,'''def healthy_child(info, child, launch_id):
    """Windows venv redirectors have a different PID from the actual Python worker."""
    if child.poll() is not None or not info.get('ok'):
        return False
    reported = info.get('launchId', '')
    if reported:
        return isinstance(reported, str) and hmac.compare_digest(reported, launch_id)
    # Backward compatibility only for old helpers without nonce support.
    try:
        legacy = updater.version_tuple(info.get('version', '')) < (1, 9, 2)
    except (ValueError, TypeError):
        return False
    return legacy and info.get('pid') == child.pid


'''),
(54,57,'''            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(child.pid), '/T', '/F'],
                               capture_output=True, timeout=10,
                               creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            else:
                import signal
                os.killpg(child.pid, signal.SIGTERM)
        except (OSError, subprocess.TimeoutExpired):
            try: child.terminate()
            except OSError: pass
'''),
(98,98,'''        launch_id = secrets.token_hex(24)
        child_env = os.environ.copy()
        child_env['VIDDOCK_LAUNCH_ID'] = launch_id
'''),
(102,103,'''                                     env=child_env, creationflags=flags,
                                     start_new_session=(os.name != 'nt'))
        (ROOT / 'helper_launcher.pid').write_text(str(child.pid), encoding='ascii')
'''),
(110,111,'            if healthy_child(ready, child, launch_id):\n'),
(117,118,'            if not healthy_child(final_probe, child, launch_id):\n'),
(122,123,'        if not healthy_child(ready, child, launch_id):\n'),
(145,145,'''        (ROOT / 'helper.pid').write_text(str(ready['pid']), encoding='ascii')
        log('Validated helper: launcher_pid=' + str(child.pid) + ', worker_pid=' + str(ready['pid']))
'''),
(169,170,'''        try: shutil.copy2(ATTEMPT_LOG,ROOT/'helper_runtime_exit.log')
        except OSError: pass
        log('Helper exited unexpectedly (exit ' + str(child.returncode) + '); saved runtime log; retrying')
''')]),
'helper/updater.py':('0c35a3e231470edca01d7e716169afaa56184228aa2ed91aac87e7de1a6cad96','699ecf173524f3fbcd3610ae92be1a65d437870439a4e965710d69c5c21a1c0b',[(5,6,"VERSION='1.9.2'\n")]),
'helper/youtube_helper.py':('5e59398080d9b21d3bd5d40097b512453b8e7aedf8aa1b103028597a5558f866','6363823e4ba80f4cc5d51539f8107459f59cbe66f4598cd43f201881489daa3c',[
(12,12,'import importlib.metadata\n'),
(47,47,'''JOBS_PATH = Path(__file__).with_name('job_journal.json')
INSTANCE_ID = uuid.uuid4().hex
# Only the local supervisor passes this one-launch identifier. Do not forward it to yt-dlp.
LAUNCH_ID = os.environ.pop('VIDDOCK_LAUNCH_ID', '')
_LAST_JOB_JOURNAL_WRITE = 0.0
JOB_JOURNAL_LIMIT = 120
'''),
(172,172,'''def dependency_versions() -> dict:
    """Report the actual helper runtime, never assume system pip is the same Python."""
    result = {'pythonVersion': '.'.join(map(str, sys.version_info[:3]))}
    for package, field in [('yt-dlp', 'ytdlpVersion'), ('curl-cffi', 'curlCffiVersion'),
                           ('yt-dlp-ejs', 'ejsVersion')]:
        try: result[field] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError: result[field] = ''
    return result


'''),
(255,255,'''def _persist_jobs(force: bool = False) -> None:
    """Durable, minimal job state; never persist media URLs or credentials.

    Caller owns LOCK. An intermittent disk error must not kill a download.
    Writes are throttled while yt-dlp emits frequent progress lines.
    """
    global _LAST_JOB_JOURNAL_WRITE
    now = time.monotonic()
    if not force and now - _LAST_JOB_JOURNAL_WRITE < 1.25:
        return
    snapshot = {}
    for job_id, job in list(JOBS.items())[-JOB_JOURNAL_LIMIT:]:
        if not re.fullmatch(r'[a-f0-9]{32}', job_id):
            continue
        state = job.get('state')
        if state not in ('queued', 'running', 'done', 'failed', 'interrupted'):
            continue
        try:
            percent = max(0.0, min(100.0, float(job.get('percent', 0) or 0)))
        except (TypeError, ValueError):
            percent = 0.0
        item = {
            'state': state,
            'percent': percent,
            'message': sanitize_diagnostic(str(job.get('message', '')))[:300],
            'updatedAt': int(time.time()),
        }
        if state == 'done' and job.get('path'):
            item['path'] = str(job['path'])[:1024]
        snapshot[job_id] = item
    try:
        store_json(JOBS_PATH, {'schema': 1, 'jobs': snapshot})
        _LAST_JOB_JOURNAL_WRITE = now
    except (OSError, ValueError) as exc:
        status_log('Unable to persist download state: ' + str(exc)[:140])


def load_jobs() -> None:
    """Recover statuses after an unexpected helper exit.

    In-progress subprocess downloads cannot be safely claimed as resumed.
    Preserve their progress and explain that the outcome is unknown.
    """
    data = load_json(JOBS_PATH)
    records = data.get('jobs', {})
    if not isinstance(records, dict):
        return
    with LOCK:
        for job_id, item in list(records.items())[-JOB_JOURNAL_LIMIT:]:
            if not isinstance(job_id, str) or not re.fullmatch(r'[a-f0-9]{32}', job_id):
                continue
            if not isinstance(item, dict):
                continue
            state = item.get('state', '')
            if state not in ('queued', 'running', 'done', 'failed', 'interrupted'):
                continue
            try:
                percent = max(0.0, min(100.0, float(item.get('percent', 0) or 0)))
            except (TypeError, ValueError):
                percent = 0.0
            recovered = state in ('queued', 'running')
            path = str(item.get('path', ''))[:1024] if state == 'done' else ''
            if state == 'done' and (not path or not Path(path).is_file()):
                recovered = True
            if recovered:
                state = 'interrupted'
                message = ('補助ツールが再起動し、動画保存の追跡が中断されました。'
                           '保存先に完成ファイルがないか確認し、必要なら動画を再検出して再試行してください。')
                path = ''
            else:
                message = sanitize_diagnostic(str(item.get('message', '')))[:300]
            JOBS[job_id] = {'state': state, 'percent': percent, 'path': path,
                            'message': message, 'recovered': recovered}
        _persist_jobs(force=True)


'''),
(257,259,'''        job = JOBS.get(job_id)
        if job is None:
            return
        previous_state = job.get('state')
        if 'message' in changes:
            changes['message'] = sanitize_diagnostic(str(changes['message']))
        job.update(changes)
        _persist_jobs(force=(previous_state != job.get('state') or
                             job.get('state') in ('done', 'failed', 'interrupted')))
'''),
(543,544,"    server_version = 'VidDock/1.9.2'\n"),
(604,605,"            self._answer(200, {'ok': True, 'version': '1.9.2', 'ytdlp': yt_dlp_command() is not None,\n"),
(609,610,'''                               'folder': get_folder(), 'pid': os.getpid(), 'instanceId': INSTANCE_ID,
                               'launchId': LAUNCH_ID, **dependency_versions(),
'''),
(626,626,'''            if not re.fullmatch(r'[a-f0-9]{32}', job_id):
                self._answer(400, {'ok': False, 'error': 'ジョブIDが不正です。'})
                return
'''),
(629,630,'''                self._answer(404, {'ok': False, 'code': 'JOB_UNKNOWN',
                                   'error': 'ジョブの記録がありません。補助ツールが別のインストール先から起動していないか確認してください。',
                                   'instanceId': INSTANCE_ID})
'''),
(631,632,'''                self._answer(200, {'ok': True, **{k:v for k,v in info.items() if k != 'key'},
                                   'instanceId': INSTANCE_ID})
'''),
(690,690,'                    _persist_jobs(force=True)\n'),
(702,702,'                _persist_jobs(force=True)\n'),
(730,730,'    load_jobs()\n'),
(740,740,'''        # Keep optional pip installations away from ongoing downloads.
        # If a challenge actually requires the optional module, the download
        # worker can explicitly request setup through wait_for_impersonation_setup.
        while True:
            with LOCK:
                busy = any(j.get('state') in ('queued', 'running') for j in JOBS.values())
            if not busy:
                break
            time.sleep(2)
''')]),
'manifest.json':('6b352feba8ce7a3318d855d45ce2b600d4fae771bcca4bcd7b6e446173c63aef','1174c162d7f455f2794ccf46cb977fa8c39efc33fefff6ba14c834fd7de51af8',[(4,5,'  "version": "1.9.2",\n')]),
'panel.js':('cd5177beead76827f8fcf72413d3c53a12231899efcdcd0c0f849087082d8495','f786d673b1adb0bd34d416e41da9addeee0b8d1f6256995222e03384e6fd2019',[
(54,54,"  if (info.state==='interrupted')return '保存中断（再試行できます）';\n"),
(70,71,"    .filter(x=>x && ['preparing','running','queued','done','failed','interrupted'].includes(x.state))\n"),
(115,116,"  $('helperStatus').textContent=`接続OK · v${result.version} · yt-dlp ${result.ytdlpVersion||'利用可'} · FFmpeg OK · ${impersonationText}`;\n"),
(163,163,"      if(result.state==='interrupted'){notice(result.message||'保存処理が中断されました。再試行できます。','error');break;}\n")])
}

def build():
    base=ROOT/'releases/VidDock191.zip'
    if hashlib.sha256(base.read_bytes()).hexdigest()!=BASE_SHA:raise RuntimeError('Base release hash mismatch')
    with zipfile.ZipFile(base) as archive:
        names=archive.namelist()
        if len(names)!=len(set(names)):raise RuntimeError('Duplicate ZIP entries')
        files={n:archive.read(n) for n in names}
    for relative,(before,after,edits) in CHANGES.items():
        name='watari_video_helper/'+relative
        original=files[name]
        if hashlib.sha256(original).hexdigest()!=before:raise RuntimeError('Base file mismatch: '+name)
        lines=original.decode('utf-8').splitlines(keepends=True)
        output=[];position=0
        for begin,end,text in edits:
            if not position<=begin<=end<=len(lines):raise RuntimeError('Invalid edit')
            output.extend(lines[position:begin]);output.append(text);position=end
        output.extend(lines[position:]);updated=''.join(output).encode('utf-8')
        if hashlib.sha256(updated).hexdigest()!=after:raise RuntimeError('New file mismatch: '+name)
        files[name]=updated
    manifest=json.loads(files['watari_video_helper/manifest.json'])
    if manifest['version']!='1.9.2' or manifest['name']!='VidDock':raise RuntimeError('Invalid identity')
    buf=io.BytesIO()
    with zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as out:
        for name in sorted(files):
            info=zipfile.ZipInfo(name,(2026,10,19,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
            out.writestr(info,files[name])
    data=buf.getvalue()
    if hashlib.sha256(data).hexdigest()!=FINAL_SHA:raise RuntimeError('ZIP differs from the tested private release')
    destination=ROOT/'releases/VidDock192.zip'
    if destination.exists() and destination.read_bytes()!=data:raise RuntimeError('Immutable release cannot change')
    destination.write_bytes(data)
    meta={'repo':'watari-naru/viddock','version':'1.9.2','asset':'releases/VidDock192.zip','sha256':FINAL_SHA,'notes':'Windows helper identity fix and durable download job state'}
    (ROOT/'update.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
    print('VERIFIED VidDock192',FINAL_SHA)
if __name__=='__main__':build()
