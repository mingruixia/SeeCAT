"""Build the SeeCAT manual (HTML, English and Chinese) from its sources.

    python Doc/manual/src/build.py          # writes Doc/manual/{en,zh}/index.html and index.html
    python Doc/manual/src/build.py --pdf    # also the PDFs (Microsoft Edge or Chrome, headless)

Sources (this folder):
    manual_en.html, manual_zh.html  chapter text; <h2>/<h3> make the table of contents
    params.json                     every form entry (export_params.m, from the software itself)
    params_zh.json                  Chinese labels and help, by "pipeline.path" or "*.path"
Placeholders in the chapter text:
    {{PARAMS pipeline sections}}     a parameter table, e.g. {{PARAMS prep Input|Preprocessing}}
    {{IMG file.png | caption}}       a figure from ../images
"""
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MAN = os.path.dirname(HERE)
P = json.load(open(os.path.join(HERE, 'params.json'), encoding='utf-8'))
ZH = json.load(open(os.path.join(HERE, 'params_zh.json'), encoding='utf-8'))
VERSION = '2.0'

UI = {
    'en': dict(title='SeeCAT 2.0 User Manual', contents='Contents', option='Option (window)', field='Batch field',
               default='Default', meaning='Meaning and advice', adv='advanced', empty='(empty)', fig='Figure',
               other='中文版', other_href='../zh/index.html', lang='en'),
    'zh': dict(title='SeeCAT 2.0 使用手册', contents='目录', option='选项（界面）', field='批处理字段',
               default='默认值', meaning='含义与设置建议', adv='高级', empty='（空）', fig='图',
               other='English', other_href='../en/index.html', lang='zh-CN'),
}


def esc(s):
    return html.escape(s, quote=False)


def help_html(text):
    """Help text of the software: paragraphs and line-broken lists."""
    out = []
    for para in text.split('\n\n'):
        lines = [esc(x) for x in para.split('\n')]
        out.append('<p>' + '<br>'.join(lines) + '</p>')
    return ''.join(out)


def zh_entry(pipe, path):
    return ZH.get(pipe + '.' + path) or ZH.get('*.' + path)


def params_table(pipe, sections, lang):
    u = UI[lang]
    rows = []
    for r in P[pipe]:
        if r['section'] not in sections:
            continue
        label, text = r['label'], r['help']
        if lang == 'zh':
            z = zh_entry(pipe, r['path'])
            if z is None:
                raise SystemExit('No Chinese text for %s.%s' % (pipe, r['path']))
            label = z['label'] + '<br><span class="en">' + esc(r['label']) + '</span>'
            text = z['help']
        else:
            label = esc(label)
        d = r['default'] if r['default'] != '' else u['empty']
        adv = ' <span class="tag">%s</span>' % u['adv'] if r['advanced'] else ''
        ch = ''
        if r['choices'] and isinstance(r['choices'], list) and all(isinstance(c, str) for c in r['choices']):
            ch = '<p class="choices">' + ' | '.join('<code>%s</code>' % esc(c) for c in r['choices']) + '</p>'
        rows.append('<tr><td>%s%s</td><td><code>%s</code></td><td><code>%s</code></td><td>%s%s</td></tr>'
                    % (label, adv, esc(r['path']), esc(d), help_html(text), ch))
    if not rows:
        raise SystemExit('No parameters for %s %s' % (pipe, sections))
    return ('<div class="wrap"><table class="params"><thead><tr><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr></thead>'
            '<tbody>%s</tbody></table></div>' % (u['option'], u['field'], u['default'], u['meaning'], ''.join(rows)))


def index_table(lang):
    names = {'prep': 'Preprocessing', 'fmriprep': 'fMRIPrep', 'fc': 'Seed FC', 'degree': 'Degree',
             'gradient': 'Gradients', 'harmonize': 'Harmonize', 'stat': 'Statistics'}
    seen = {}
    for pipe, rows in P.items():
        for r in rows:
            label = r['label']
            if lang == 'zh':
                z = zh_entry(pipe, r['path'])
                label = z['label'] if z else label
            e = seen.setdefault(r['path'], {'label': label, 'pipes': []})
            e['pipes'].append(names[pipe])
    head = ('Batch field', 'Option', 'Pages') if lang == 'en' else ('批处理字段', '选项', '页面')
    rows = ''.join('<tr><td><code>%s</code></td><td>%s</td><td>%s</td></tr>' % (esc(k), esc(v['label']), ', '.join(v['pipes']))
                   for k, v in sorted(seen.items()))
    return '<div class="wrap"><table><thead><tr><th>%s</th><th>%s</th><th>%s</th></tr></thead><tbody>%s</tbody></table></div>' % (head + (rows,))


def build(lang):
    u = UI[lang]
    parts = sorted(f for f in os.listdir(HERE) if re.match(r'manual_%s_part\d+\.html$' % lang, f))
    src = '\n'.join(open(os.path.join(HERE, f), encoding='utf-8').read() for f in parts)
    src = src.replace('{{INDEX}}', index_table(lang))
    src = re.sub(r'\{\{PARAMS (\w+) ([^}]+)\}\}', lambda m: params_table(m.group(1), m.group(2).split('|'), lang), src)
    nfig = [0]

    def fig(m):
        nfig[0] += 1
        f, cap = m.group(1).strip(), m.group(2).strip()
        if not os.path.exists(os.path.join(MAN, 'images', f)):
            print('  missing image', f)
        return ('<figure><a href="../images/%s"><img src="../images/%s" alt="%s" loading="lazy"></a>'
                '<figcaption><b>%s %d.</b> %s</figcaption></figure>' % (f, f, esc(cap), u['fig'], nfig[0], cap))
    src = re.sub(r'\{\{IMG ([^|}]+)\|([^}]+)\}\}', fig, src)
    # numbered headings and the table of contents
    toc = []
    n2 = [0, 0]

    def head(m):
        level, attrs, text = m.group(1), m.group(2), m.group(3)
        if level == '2':
            n2[0] += 1
            n2[1] = 0
            num = '%d' % n2[0]
        else:
            n2[1] += 1
            num = '%d.%d' % (n2[0], n2[1])
        ident = 's' + num.replace('.', '-')
        plain = re.sub('<[^>]+>', '', text)
        toc.append((level, num, ident, plain))
        return '<h%s id="%s"%s><span class="num">%s</span> %s</h%s>' % (level, ident, attrs, num, text, level)
    src = re.sub(r'<h([23])([^>]*)>(.*?)</h\1>', head, src)
    # a table's heading row as <thead>, so that printed tables repeat it on every page
    src = re.sub(r'<table([^>]*)>\s*(<tr>(?:\s*<th[^>]*>.*?</th>)+\s*</tr>)', r'<table\1><thead>\2</thead>',
                 src, flags=re.S)
    items = []
    for level, num, ident, plain in toc:
        cls = 'l2' if level == '2' else 'l3'
        items.append('<li class="%s"><a href="#%s">%s %s</a></li>' % (cls, ident, num, esc(plain)))
    tpl = open(os.path.join(HERE, 'template.html'), encoding='utf-8').read()
    css = open(os.path.join(HERE, 'manual.css'), encoding='utf-8').read()
    out = (tpl.replace('{{LANG}}', u['lang']).replace('{{TITLE}}', u['title']).replace('{{CSS}}', css)
           .replace('{{CONTENTS}}', u['contents']).replace('{{TOC}}', '\n'.join(items))
           .replace('{{OTHER}}', u['other']).replace('{{OTHER_HREF}}', u['other_href'])
           .replace('{{BODY}}', src).replace('{{VERSION}}', VERSION))
    d = os.path.join(MAN, lang)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, 'index.html'), 'w', encoding='utf-8').write(out)
    print('%s: %d sections, %d figures' % (lang, len(toc), nfig[0]))


def pdf(lang):
    browsers = [r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
                r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
                r'C:\Program Files\Google\Chrome\Application\chrome.exe']
    exe = next((b for b in browsers if os.path.exists(b)), None) or shutil.which('msedge') or shutil.which('chrome')
    if exe is None:
        raise SystemExit('No Edge or Chrome found for the PDF.')
    src = os.path.join(MAN, lang, 'index.html')
    name = {'en': 'SeeCAT_Manual_EN.pdf', 'zh': 'SeeCAT_Manual_ZH.pdf'}[lang]
    out = os.path.join(MAN, name)
    if os.path.exists(out):
        os.remove(out)
    profile = tempfile.mkdtemp()                  # a fresh profile: works while the browser is open
    try:
        subprocess.run([exe, '--headless=new', '--disable-gpu', '--no-pdf-header-footer', '--user-data-dir=' + profile,
                        '--print-to-pdf=' + out, '--virtual-time-budget=20000', '--generate-pdf-document-outline',
                        'file:///' + src.replace('\\', '/')], check=True, timeout=600)
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    if not os.path.exists(out):
        raise SystemExit('The browser wrote no PDF: ' + out)
    print('PDF', out, os.path.getsize(out) // 1024, 'kB')


if __name__ == '__main__':
    for lang in ('en', 'zh'):
        if any(f.startswith('manual_%s_part' % lang) for f in os.listdir(HERE)):
            build(lang)
            if '--pdf' in sys.argv:
                pdf(lang)
    open(os.path.join(MAN, 'index.html'), 'w', encoding='utf-8').write(
        '<!doctype html><html><head><meta charset="utf-8"><title>SeeCAT Manual</title>'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>body{font:16px system-ui,sans-serif;max-width:560px;margin:15vh auto;padding:0 16px;color:#1d2433}'
        'a{display:block;margin:12px 0;font-size:20px}@media (prefers-color-scheme:dark){body{background:#14171f;color:#e4e7ee}a{color:#8fb0ff}}</style>'
        '</head><body><h1>SeeCAT 2.0</h1><a href="en/index.html">User Manual (English)</a>'
        '<a href="zh/index.html">使用手册（中文）</a><p>PDF: <a href="SeeCAT_Manual_EN.pdf" style="display:inline;font-size:16px">English</a> · '
        '<a href="SeeCAT_Manual_ZH.pdf" style="display:inline;font-size:16px">中文</a></p></body></html>')
