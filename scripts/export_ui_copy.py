import json,re
from pathlib import Path
import argparse
args=argparse.ArgumentParser()
args.add_argument('--output',default='docs/ui-copy-review/copy-current.md')
options=args.parse_args()
root=Path(__file__).resolve().parents[1]
rows=[]
# Literal copy is extracted with source locations; dynamic expressions remain in
# source and are checked against rendered screens, not treated as full sentences.
for p in sorted((root/'godot/scripts').glob('*.gd')):
    for m in re.finditer(r'"(?:\\.|[^"\\])*"',p.read_text()):
        raw=m.group()[1:-1]
        if len(raw)<8 or ' ' not in raw or 'res://' in raw or raw.startswith('user://') or not re.search('[A-Za-z]{3}',raw):continue
        value=raw.replace('\\n','\n').replace('\\t',' ').replace('\\"','"')
        line=p.read_text()[:m.start()].count('\n')+1
        rows.append((str(p.relative_to(root))+':'+str(line),value))
for file in ['godot/content/lantern_quay.json','godot/content/rpg_catalog.json','godot/content/garden_chapter.json']:
    data=json.loads((root/file).read_text())
    def visit(value,key=''):
        if isinstance(value,dict):
            for k,v in value.items():visit(v,key+'/'+k)
        elif isinstance(value,list):
            for i,v in enumerate(value):visit(v,key+'/'+str(i))
        elif isinstance(value,str) and ' ' in value and len(value)>12:
            rows.append((file+'#'+key,value))
    visit(data)
seen={}
for ref,text in rows:seen.setdefault(text,[]).append(ref)
out=['# Oathshaper UI copy inventory','', 'Source-literal extraction. Repeated strings are deduplicated; references identify their screen source. Dynamic values, runtime visibility and layout require Godot verification.','']
for text,refs in seen.items():
    out+=['## '+refs[0],'',text,'']
    if len(refs)>1:out+=['Also: '+', '.join(refs[1:]),'']
(root/options.output).write_text('\n'.join(out))
print(f'{len(seen)} unique strings; '+str(sum(len(t.split()) for t in seen))+' words')
