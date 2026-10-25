"""本地录音的起音与分频段持续和声特征；不做人声分离。"""
from pathlib import Path
import subprocess
import numpy as np

def extract(path: Path, ffmpeg: str, destination: Path):
    if destination.exists():
        return np.load(destination)
    raw=subprocess.run([ffmpeg,'-v','error','-i',str(path),'-vn','-ar','11025',
                        '-ac','1','-f','f32le','pipe:1'],check=True,capture_output=True).stdout
    samples=np.frombuffer(raw,dtype='<f4')
    sr,size,hop=11025,1024,128
    frames=np.lib.stride_tricks.sliding_window_view(samples,size)[::hop]
    spec=np.abs(np.fft.rfft(frames*np.hanning(size),axis=1)).astype('float32')
    freq=np.fft.rfftfreq(size,1/sr)
    times=(np.arange(len(frames))*hop+size/2)/sr
    flux=np.maximum(np.diff(np.log1p(spec*8),axis=0,prepend=np.log1p(spec[:1]*8)),0)
    bands=[flux[:,(freq>=a)&(freq<b)].mean(1) for a,b in ((35,220),(220,2500),(2500,5500))]
    low,mid,high=[a/(a.mean()+1e-9) for a in bands]
    padded=np.pad(spec,((8,8),(0,0)),mode='edge')
    harmonic=np.empty_like(spec)
    for a in range(0,len(spec),256):
        b=min(a+256,len(spec))
        temporal=np.median(np.lib.stride_tricks.sliding_window_view(padded[a:b+16],17,axis=0),axis=-1)
        percussive=np.median(np.lib.stride_tricks.sliding_window_view(
            np.pad(spec[a:b],((0,0),(8,8)),mode='edge'),17,axis=1),axis=-1)
        harmonic[a:b]=spec[a:b]*temporal**2/(temporal**2+percussive**2+1e-9)
    midi=np.rint(69+12*np.log2(np.maximum(freq,1)/440)).astype(int)
    features=dict(times=times,low=low,mid=mid,high=high,rms=np.sqrt((frames**2).mean(1)))
    for lane,(lo,hi) in enumerate(((65,500),(300,2600))):
        ch=np.zeros((len(spec),12),dtype='float32')
        for k in range(12):
            selected=(freq>=lo)&(freq<hi)&(midi%12==k)
            ch[:,k]=np.sqrt((harmonic[:,selected]**2).sum(1))
        energy=np.linalg.norm(ch,axis=1)
        ch/=energy[:,None]+1e-9
        change=np.linalg.norm(np.maximum(ch-np.roll(ch,5,axis=0),0),axis=1)
        change[:5]=0
        features[f'chroma{lane}']=ch
        features[f'energy{lane}']=energy
        features[f'change{lane}']=change
    destination.parent.mkdir(parents=True,exist_ok=True)
    np.savez_compressed(destination,**features)
    return np.load(destination)
