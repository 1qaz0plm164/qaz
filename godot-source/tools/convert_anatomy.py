# Generated adaptation by CodeRabbit. Input assets are CC0.
import json,math,pathlib
p=pathlib.Path(__file__).resolve().parents[1]/'assets/characters';p.mkdir(parents=True,exist_ok=True)
v=[];uv=[];faces=[];group=''
for line in open(p/'source/base.obj'):
 a=line.split()
 if not a:continue
 if a[0]=='v':v.append(list(map(float,a[1:])))
 if a[0]=='vt':uv.append(list(map(float,a[1:])))
 if a[0]=='g':group=a[1]
 if a[0]=='f' and group=='body':
  f=[tuple(int(i)-1 for i in x.split('/')[:2]) for x in a[1:]]
  for i in range(1,len(f)-1):faces.append([f[0],f[i],f[i+1]])
s=json.load(open(p/'source/default.mhskel'));weights=json.load(open(p/'source/default_weights.mhw'))['weights']
names=['torso','head','armL','elbowL','legL','kneeL','footL','armR','elbowR','legR','kneeR','footR']
origins={'torso':'spine05','head':'head'}
for side in 'LR':
 for dest,src in [('arm','upperarm01'),('elbow','lowerarm01'),('leg','upperleg01'),('knee','lowerleg01'),('foot','foot')]:origins[dest+side]=src+'.'+side
src={}
for key,bone in origins.items():
 ids=s['joints'][s['bones'][bone]['head']];src[key]=[sum(v[i][j] for i in ids)/len(ids) for j in range(3)]

def cat(b):
 side=b[-1] if b.endswith(('.L','.R')) else ''
 lineage=[];cursor=b
 while cursor in s['bones']:
  lineage.append(cursor);cursor=s['bones'][cursor]['parent']
 if 'head' in lineage or b.startswith('neck'):return 'head'
 if any(x.startswith('lowerarm') for x in lineage):return 'elbow'+side
 if any(x.startswith('upperarm') for x in lineage):return 'arm'+side
 if any(x.startswith('foot') for x in lineage):return 'foot'+side
 if any(x.startswith('lowerleg') for x in lineage):return 'knee'+side
 if any(x.startswith('upperleg') for x in lineage):return 'leg'+side
 return 'torso'
ws=[{} for _ in v]
for bone,items in weights.items():
 key=cat(bone)
 for idx,weight in items:ws[idx][key]=ws[idx].get(key,0)+weight
# Original is decimetres, Y centred around pelvis and forward +Z.
# Store source and weights; runtime binds it to existing animation anchors.
data={'names':names,'origins':src,'vertices':v,'uv':uv,'faces':faces,'weights':[sorted(x.items(),key=lambda y:-y[1])[:4] or [('torso',1)] for x in ws]}
(p/'anatomy.json').write_text(json.dumps(data,separators=(',',':')))
