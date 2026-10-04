"""Bundle verified build artifacts and editable source (Python standard library only)."""
from pathlib import Path
import zipfile, shutil
p=Path(__file__).resolve().parent
o=p.parent/'deliverables';o.mkdir(exist_ok=True)
for plat in ['windows','linux','web']:
 d=p/'builds'/plat
 for f in ['README.md','LICENSE.txt']:
  shutil.copy(p/f,d/f)
 shutil.copy(p/'assets/FONT_LICENSE.txt',d/'FONT_LICENSE.txt')
 with zipfile.ZipFile(o/f'MoleGarden-{plat}.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for f in d.iterdir():
   if f.is_file():z.write(f,f'MoleGarden-{plat}/{f.name}')
with zipfile.ZipFile(o/'MoleGarden-Godot-Source.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in p.rglob('*'):
  if f.is_file() and not any(x in f.parts for x in ['.godot','builds','.git','export_templates']) and f.suffix!='.import':z.write(f,'MoleGarden/'+str(f.relative_to(p)))
for f in sorted(o.glob('*.zip')):
 with zipfile.ZipFile(f) as z:assert z.testzip() is None
 print(f.name,round(f.stat().st_size/1024/1024,2),'MiB, archive verified')
