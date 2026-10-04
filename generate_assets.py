from PIL import Image, ImageDraw
import random, math, wave, struct
from pathlib import Path
P=Path(__file__).parent/'assets'; P.mkdir(exist_ok=True)
random.seed(18)
def save(name,img): img.save(P/(name+'.png'))
def mole(name,gold=False,bomb=False):
 im=Image.new('RGBA',(48,48)); d=ImageDraw.Draw(im)
 if bomb:
  d.rectangle((26,4,29,13),fill='#7b5e48'); d.rectangle((29,2,32,6),fill='#ffca63'); d.rectangle((33,0,35,3),fill='#fff0a3')
  d.ellipse((8,12,40,43),fill='#292b3c'); d.rectangle((9,22,39,35),fill='#292b3c'); d.ellipse((13,15,35,35),fill='#464b5b'); d.rectangle((15,17,19,23),fill='#757c84'); d.rectangle((20,25,23,34),fill='#ffbb8a'); d.rectangle((20,37,23,39),fill='#ffbb8a')
 else:
  outline='#644235'; body='#dfac71' if not gold else '#e9ae38'; light='#f1cd97' if not gold else '#ffe49c'
  d.rectangle((11,11,17,21),fill=outline); d.rectangle((31,11,37,21),fill=outline); d.rectangle((13,13,16,18),fill='#e49a86'); d.rectangle((32,13,35,18),fill='#e49a86')
  d.rounded_rectangle((9,13,39,44),8,fill=outline); d.rounded_rectangle((12,15,36,43),7,fill=body); d.rectangle((14,19,34,38),fill=body)
  d.ellipse((15,29,33,42),fill=light); d.rectangle((16,24,19,29),fill='#3c3135'); d.rectangle((29,24,32,29),fill='#3c3135'); d.point((16,24),fill='white'); d.point((29,24),fill='white')
  d.rectangle((21,30,26,33),fill='#965349'); d.rectangle((23,33,24,35),fill='#644235'); d.rectangle((10,32,14,34),fill='#e59381'); d.rectangle((34,32,38,34),fill='#e59381'); d.rectangle((5,38,13,42),fill=body); d.rectangle((35,38,43,42),fill=body)
  if gold:
   d.polygon([(14,13),(12,4),(19,8),(24,1),(29,8),(36,4),(34,13)],fill='#fff0aa');d.rectangle((15,12,33,15),fill='#ffcd45');d.rectangle((23,7,25,10),fill='#ee9369')
 save(name,im)
mole('mole');mole('gold',True);mole('bomb',bomb=True)
im=Image.new('RGBA',(60,25));d=ImageDraw.Draw(im);d.ellipse((1,5,58,24),fill='#33573d');d.ellipse((3,1,56,21),fill='#b88858');d.ellipse((5,2,54,18),fill='#e0b477');d.ellipse((8,5,51,19),fill='#513d32');d.ellipse((11,7,49,18),fill='#392f2c');d.rectangle((8,18,51,21),fill='#9a713f');save('hole',im)
im=Image.new('RGBA',(48,48));d=ImageDraw.Draw(im);d.rectangle((24,16,29,44),fill='#694939');d.rectangle((25,19,27,42),fill='#ba8c53');d.rectangle((9,6,39,22),fill='#493d44');d.rectangle((7,8,40,19),fill='#cbd2c6');d.rectangle((10,7,36,11),fill='#f5edcf');d.rectangle((9,18,38,22),fill='#849d90');save('hammer',im)
im=Image.new('RGBA',(16,20));d=ImageDraw.Draw(im);d.rectangle((7,8,8,19),fill='#427a46');d.rectangle((3,13,7,15),fill='#4e9652');d.rectangle((9,10,12,12),fill='#4e9652');d.rectangle((4,1,10,10),fill='#f6d999');d.rectangle((1,4,13,7),fill='#f6d999');d.rectangle((5,4,9,7),fill='#e9a35c');save('flower',im)
im=Image.new('RGB',(280,200),'#152f2a');d=ImageDraw.Draw(im)
for y in range(0,200,8):
 for x in range(0,280,8):
  if random.random()<.4:d.rectangle((x,y,x+1,y+1),fill='#1b3930')
save('background',im)
def sound(name,freq,dur,kind='sine'):
 n=int(22050*dur);v=[]
 for i in range(n):
  t=i/22050;en=(1-i/n)**2
  f=freq*(1+.8*i/n) if name!='bomb_sound' else freq*(1-.7*i/n)
  s=math.sin(2*math.pi*f*t)
  if kind=='square':s=1 if s>0 else -1
  v.append(int(11000*s*en))
 with wave.open(str(P/(name+'.wav')),'wb') as w:w.setparams((1,2,22050,n,'NONE','not compressed'));w.writeframes(struct.pack('<'+'h'*n,*v))
sound('hit',470,.12);sound('gold_sound',870,.3);sound('bomb_sound',120,.32,'square');sound('miss',180,.12);sound('start',620,.25)
print('Original pixel art and synthesized audio generated.')
