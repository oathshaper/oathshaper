#!/usr/bin/env python3
"""Original synthesized feedback. No game recordings or third-party samples."""
import math, random, struct, wave
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
RATE=24000
rng=random.Random(721)
for name, duration in [('select',.08),('queue',.15),('reject',.18),('pause',.20),('strike',.30),('miss',.18),('heal',.65),('power',.4)]:
    samples=[]
    noise=0.
    for n in range(int(RATE*duration)):
        t=n/RATE; u=t/duration
        envelope=min(1,t/.006)*(1-u)**2
        if name in ('strike','miss'):
            noise=noise*.5+rng.uniform(-1,1)*.5
            value=noise*.55
            if name=='strike':
                value+=sum(math.sin(2*math.pi*f*t)*math.exp(-t*decay) for f,decay in [(1690,14),(2731,25),(4513,38)])*.15
        else:
            freq={'select':740,'queue':620 if u<.45 else 930,'reject':185,'pause':440 if u<.5 else 330,'heal':520+u*260,'power':145+u*210}[name]
            value=math.sin(2*math.pi*freq*t)*.5+math.sin(2*math.pi*freq*2*t)*.12
        samples.append(int(max(-1,min(1,value*envelope)) * 21000))
    path=ROOT/'godot/assets/audio/combat'/f'{name}.wav';path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE)
        out.writeframes(struct.pack('<'+'h'*len(samples),*samples))
print('Generated 8 original mono PCM cues')
