import re, json, sys
src, out = sys.argv[1], sys.argv[2]
lines = open(src, encoding='utf-8').read().split('\n')
HDR = re.compile(r'^Saudi Health Holding Company Integrated Cluster Care Standards\s+(.*?)\s*$')
manual = 'Integrated Cluster Care Standards'
clean = []
for l in lines:
    l = l.replace('\f','')
    m = HDR.match(l.replace('\t', ' '))
    if m:
        manual = m.group(1).strip() or manual
        continue
    if re.fullmatch(r'\s*\d{1,3}\s*', l) or '\f' in l and re.fullmatch(r'\f?\s*\d*\s*', l):
        continue
    clean.append((manual, l.replace('\f', '')))
stds = []
cur = None; mode = None; me_cur = None
def flush():
    global cur
    if cur:
        cur['statement'] = ' '.join(cur['statement'].split())
        cur['intent'] = ' '.join(cur['intent'].split())[:1500]
        cur['elements'] = [' '.join(e.split()) for e in cur['elements']]
        if cur['statement']:
            stds.append(cur)
    cur = None
chapter = ''
for man, l in clean:
    s = l.strip()
    m = re.match(r'^Standard ([A-Z]{2,6}\.[0-9][0-9.]*)$', s)
    if m:
        flush()
        cur = dict(id=m.group(1), manual=man, chapter=m.group(1).split('.')[0], group=chapter, statement='', intent='', elements=[])
        mode = 'stmt'; continue
    if cur is None:
        if s and len(s) < 90 and not s.endswith('.') and not re.search(r'\.{5}', s):
            chapter = s
        continue
    if re.match(r'^Measurable Elements of ', s):
        mode = 'me'; continue
    if re.match(r'^Intent of ', s):
        mode = 'intent'; continue
    if mode == 'stmt':
        if not s:
            if cur['statement']: mode = 'gap'
            continue
        cur['statement'] += ' ' + s
    elif mode == 'intent':
        cur['intent'] += ' ' + s
    elif mode == 'me':
        mm = re.match(r'^(\d{1,2})\.\s+(?:D\s+|R\s+)?(.*)$', s)
        ind = len(l) - len(l.lstrip(' '))
        if s and ind >= 12 and len(s) < 80 and not s.endswith('.') and not s.startswith('•') and not mm:
            mode = 'gap'; chapter = s; continue
        if mm and l.startswith('   '):
            cur['elements'].append(mm.group(2))
        elif s and cur['elements']:
            if len(s) < 80 and re.match(r'^[A-Z][A-Za-z ,&\-/()]+$', s) and not l.startswith('   '):
                mode = 'gap'; chapter = s; continue
            cur['elements'][-1] += ' ' + s
    elif mode == 'gap':
        if s and len(s) < 90 and not s.endswith('.'):
            chapter = s
flush()
def okgroup(g):
    return bool(g) and g[0].isupper() and not g.startswith(('•','(')) and len(g) > 4
last = {}
for x in stds:
    if not okgroup(x['group']):
        x['group'] = last.get((x['manual'], x['chapter']), '')
    last[(x['manual'], x['chapter'])] = x['group']
# dedupe ids per manual
seen = set(); res = []
for s in stds:
    k = (s['manual'], s['id'])
    if k in seen: continue
    seen.add(k); res.append(s)
json.dump(res, open(out, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
from collections import Counter
print(len(res), Counter(s['manual'] for s in res))
print(json.dumps([x for x in res if x['id']=='IPSG.02.00'][0], indent=1)[:1800])
print(sum(1 for s in res if not s['elements']), 'without MEs')
