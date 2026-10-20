"""Rebuild the tested 193 archive from immutable public 192; refuse hash drift."""
from pathlib import Path
import hashlib, io, json, zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE_SHA256='54b022157ee50c8f95ea731eaca286f32045fe331eba406eb34f3a21a80c6fc9'
EXPECTED_SHA256='acb6b906b3a5424c1c53ca75c1945ee95579ba9994a99fdf70f78b146e0fb451'

def once(text, old, new):
    if text.count(old)!=1:
        raise RuntimeError('Source mismatch for '+repr(old[:90]))
    return text.replace(old,new,1)

def patch_helper(s):
    s=once(s,"return ['--extractor-args', 'generic:impersonate'] if enabled else []",'''# The extractor arg only covers the first request. The global option
    # also covers variant playlists and segment requests. Keep HLS in
    # yt-dlp's networking stack instead of an external ffmpeg downloader.
    return (['--impersonate', 'chrome', '--extractor-args', 'generic:impersonate=chrome',
             '--downloader', 'm3u8:native', '--concurrent-fragments', '1',
             '--abort-on-unavailable-fragments', '--fragment-retries', '2',
             '--retries', '2'] if enabled else [])''')
    anchor='\ndef wait_for_impersonation_setup(seconds: float = 45) -> bool:'
    addition='''
def hls_forbidden(text: str) -> bool:
    lower = text.lower()
    return ('[generic]' in lower and 'failed to download m3u8 information' in lower
            and bool(re.search(r'http(?: error)?\\s+403\\b', lower)))


def browser_transport_available(command: list[str]) -> bool:
    """Check usable targets in the exact yt-dlp child, not only find_spec."""
    try:
        result = subprocess.run(
            command + ['--ignore-config', '--no-plugin-dirs', '--no-colors',
                       '--list-impersonate-targets'],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
            encoding='utf-8', errors='replace', timeout=15,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0) if os.name == 'nt' else 0)
        return result.returncode == 0 and any(
            re.match(r'^\\s*chrome(?:[-\\s])', line, re.I) and 'unavailable' not in line.lower()
            for line in result.stdout.splitlines())
    except (OSError, subprocess.TimeoutExpired):
        return False

'''
    s=once(s,anchor,'\n'+addition+anchor)
    s=once(s,"            source = None\n            for attempt", "            source = None\n            retry_reason = ''\n            for attempt")
    old="""                    set_job(job_id, state='running', percent=0,
                            message='Cloudflareの判定を検出。yt-dlpの公式ブラウザ通信方式で1回再試行しています...')"""
    new="""                    if not browser_transport_available(command):
                        set_job(job_id, state='failed', message=(
                            'yt-dlpでChrome互換通信を利用できません。curl_cffiの導入有無ではなく、'
                            'このPython環境での対応状況を確認してください。'))
                        return
                    reason = 'Cloudflareの判定を検出。' if retry_reason == 'cloudflare' else 'HLS再生リストが403で拒否されました。'
                    set_job(job_id, state='running', percent=0, message=reason +
                            'ページ・再生リスト・分割動画を同じChrome互換通信で1回再試行しています...')"""
    s=once(s,old,new)
    s=once(s,"                    for name, value in extra_headers.items():\n                        args += ['--add-header', f'{name}:{value}']", """                    for name, value in extra_headers.items():
                        # Let curl_cffi choose the UA matching its TLS profile.
                        # Referer, Origin and Accept-Language remain unchanged.
                        if impersonate and name == 'User-Agent':
                            continue
                        args += ['--add-header', f'{name}:{value}']""")
    s=once(s,"                cloudflare_blocked = False\n                kwargs", "                cloudflare_blocked = False\n                hls_blocked = False\n                kwargs")
    s=once(s,"                    if cloudflare_challenge(line):\n                        cloudflare_blocked = True", """                    if cloudflare_challenge(line):
                        cloudflare_blocked = True
                    if hls_forbidden(line):
                        hls_blocked = True""")
    s=once(s,"                if cloudflare_blocked and not impersonate and site in ('tokyomotion', 'media'):\n                    continue", """                if (cloudflare_blocked or hls_blocked) and not impersonate and site in ('tokyomotion', 'media'):
                    retry_reason = 'cloudflare' if cloudflare_blocked else 'hls403'
                    continue""")
    s=once(s,"                if cloudflare_blocked:\n                    detail =", """                if impersonate and (hls_blocked or cloudflare_blocked or re.search(r'403|Forbidden', detail, re.I)):
                    set_job(job_id, state='failed', message=(
                        'Chrome互換通信でも動画配信元が403を返しました。'
                        '再試行は1回で停止しました。ブラウザのセッション条件などが別途必要な可能性があります。 / '
                        + sanitize_diagnostic(detail)[:130]))
                    return
                if cloudflare_blocked:
                    detail =""")
    return s.replace('1.9.2','1.9.3')


def main():
    current=json.loads((ROOT/'update.json').read_text(encoding='utf-8-sig'))
    if current.get('repo')!='watari-naru/viddock' or current.get('version') not in ('1.9.2','1.9.3'):
        raise RuntimeError('Unexpected public release pointer; refusing to downgrade')
    binary=(ROOT/'releases/VidDock192.zip').read_bytes()
    if hashlib.sha256(binary).hexdigest()!=BASE_SHA256:
        raise RuntimeError('Public base checksum mismatch')
    with zipfile.ZipFile(io.BytesIO(binary)) as source:
        entries={i.filename:source.read(i) for i in source.infolist() if not i.is_dir()}
    prefix='watari_video_helper/'
    h=prefix+'helper/youtube_helper.py'
    helper=patch_helper(entries[h].decode('utf-8'))
    compile(helper,h,'exec')
    entries[h]=helper.encode('utf-8')
    u=prefix+'helper/updater.py'
    entries[u]=once(entries[u].decode('utf-8'),"VERSION='1.9.2'","VERSION='1.9.3'").encode('utf-8')
    m=prefix+'manifest.json'
    manifest=json.loads(entries[m]);manifest['version']='1.9.3'
    entries[m]=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    entries[prefix+'RELEASE_NOTES.txt']=b'VidDock193\nFixes the browser transport retry scope for HLS playlists and fragments. Uses one bounded retry, native HLS and a usable Chrome target check. No credential extraction or DRM decryption added.\n'
    result=io.BytesIO()
    with zipfile.ZipFile(result,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name in sorted(entries):
            info=zipfile.ZipInfo(name,(2026,10,19,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
            archive.writestr(info,entries[name])
    data=result.getvalue()
    digest=hashlib.sha256(data).hexdigest()
    if digest!=EXPECTED_SHA256:
        raise RuntimeError('Reconstructed bytes differ from tested private release: '+digest)
    output=ROOT/'releases/VidDock193.zip'
    if output.exists() and output.read_bytes()!=data:
        raise RuntimeError('Existing release is immutable')
    output.write_bytes(data)
    metadata={'repo':'watari-naru/viddock','version':'1.9.3','asset':'releases/VidDock193.zip',
              'sha256':digest,'notes':'HLS playlist and fragment browser transport repair'}
    (ROOT/'update.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('VERIFIED: exact tested VidDock193 archive',digest)

if __name__=='__main__':main()
