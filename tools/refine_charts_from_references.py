"""按参考视频中观察到的分组/交互方式修订四曲五谱。

运行：python tools/refine_charts_from_references.py --ffmpeg <ffmpeg路径>
依赖：numpy；只分析本地有权使用的录音，缓存/审计与基线在 .local 下。
视频提供编排形态的证据，不把别的曲目的时刻直接移植过来。
"""
from pathlib import Path
import argparse,collections,json,hashlib,shutil
import numpy as np
from audio_features import extract

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--ffmpeg',required=True)
args=parser.parse_args()
game=ROOT/'game';local=ROOT/'.local';baseline=local/'v08-before-video'
playlist=json.loads((game/'playlist.json').read_text(encoding='utf8'))
reports=[]
pending=[]

def dump(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')

for entry in playlist:
    first=json.loads((game/entry['charts'][0]['info'][6:]).read_text(encoding='utf8'))
    audio=game/first['audio'][6:]
    audio_hash=hashlib.sha256(audio.read_bytes()).hexdigest()
    assert audio_hash==first['audio_sha256'],entry['id']
    # Changed recordings must never reuse features cached for an earlier file.
    f=extract(audio,args.ffmpeg,local/'music-features'/(entry['id']+'-'+audio_hash[:16]+'.npz'))
    ft=f['times']
    for chart_entry in entry['charts']:
        chartpath=game/chart_entry['chart'][6:];infopath=game/chart_entry['info'][6:]
        oldpath=baseline/chartpath.relative_to(game)
        oldinfo=baseline/infopath.relative_to(game)
        for current,backup in ((chartpath,oldpath),(infopath,oldinfo)):
            backup.parent.mkdir(parents=True,exist_ok=True)
            if not backup.exists():shutil.copy2(current,backup)
        info=json.loads(oldinfo.read_text(encoding='utf8'))
        old=json.loads(oldpath.read_text(encoding='utf8'))
        sid=entry['id'];hard=chart_entry['label']=='挑战';melody=sid=='never_more'
        beat,phase,duration=60/info['bpm'],info['grid_offset_seconds'],info['duration']
        # Quarter-beat resolution is used for evidence and sustain tails.
        grid=np.arange(0,(duration-2-phase)/beat,.25);times=phase+grid*beat
        def at(name,t):return np.interp(t,ft,f[name])
        def region(b):
            return next((s for s in info['sections'] if s['start']<=phase+b*beat<s['end']),info['sections'][-1])
        energy=at('rms',times)
        band=[]
        for name in ('low','mid','high'):
            # 21ms correction belongs to the source-onset measurement, not to
            # device latency. Local maxima are only searched within 30ms.
            values=[]
            for t in times:
                w=(ft>=t-.021-.03)&(ft<=t-.021+.03)
                values.append(float(np.max(f[name][w])) if w.any() else 0.)
            band.append(np.asarray(values))
        bass,mid,high=band
        tonal=[]
        for lane in (0,1):
            ch=np.stack([np.interp(times+.04,ft,f[f'chroma{lane}'][:,k]) for k in range(12)],axis=1)
            tonal.append((ch,at(f'energy{lane}',times+.04),at(f'change{lane}',times+.02)))
        strength=.45*bass+.45*mid+.10*high
        notes=[];groups=[];phrase_patterns=[];recalled=0
        # Source-first event selection. No bar-level top-N truncation, which
        # previously split a musical short group into irregular isolated taps.
        for start in range(0,int(grid[-1])+1,8):
            idx=np.flatnonzero((grid>=start)&(grid<start+8))
            if not len(idx):continue
            sec=region(start);load=float(sec.get('load',.6));voice=sec.get('focus','mixed')
            quiet=load<.33
            lead=.30*bass+.60*mid+.10*high if melody or voice in ('harmony','response') else strength
            # The baseline is measured on playable eighth-note positions;
            # including empty 16th slots made almost every eighth look salient.
            eighth_idx=idx[(np.rint(grid[idx]*4).astype(int)%2)==0]
            loc=lead[eighth_idx]
            # An entire low-intensity phrase foregrounds one gesture; its
            # weak accompaniment is not used to fill every available beat.
            threshold=max(.55,float(np.quantile(loc,.22 if hard else .36)))
            if quiet:threshold=max(threshold,float(np.quantile(loc,.73)))
            selected=[]
            for i in idx:
                b=grid[i];t=times[i]
                if t<2 or energy[i]<max(.012,float(np.quantile(energy,.8))*.10):continue
                if lead[i]<threshold:continue
                if int(round(b*4))%2:
                    # 16ths must belong to a supported cluster. A lone strong
                    # 16th after a weak valley is not sprayed into the chart.
                    if not hard or load<.65:continue
                    neighbors=[j for j in (i-1,i+1) if 0<=j<len(grid)]
                    if lead[i]<max(threshold*1.2,1.05) or not any(lead[j]>=threshold for j in neighbors):continue
                selected.append(int(i))
            # Close only supported half-beat holes inside an audible run.
            # This avoids a cap arbitrarily deleting its third/fourth attack.
            for i in idx:
                if int(round(grid[i]*4))%2 or i in selected or i<2 or i+2>=len(grid):continue
                if i-2 in selected and i+2 in selected and lead[i]>=max(.52,threshold*.78) and not quiet:
                    selected.append(int(i))
            selected.sort()
            runs=[]
            for i in selected:
                if not runs or grid[i]-grid[runs[-1][-1]]>.50001:runs.append([i])
                else:runs[-1].append(i)
            # Quiet passages retain the strongest whole group, rather than a
            # weak single every beat. No gesture is added merely to fill time.
            clipped=[]
            for row in runs:
                # Split long runs at the source's own accents, not at every
                # fourth/eighth object index. Short intact runs keep their form.
                if len(row)<=4:
                    clipped.append(row);continue
                length=len(row);best=[-1e9]*(length+1);parts=[None]*(length+1);best[0]=0
                for end in range(1,length+1):
                    for count in (2,3,4):
                        begin=end-count
                        if begin<0 or best[begin]<-1e8:continue
                        onset=float(lead[row[begin]])
                        prior=float(np.mean(lead[row[max(0,begin-2):begin]])) if begin else onset
                        accent=min(1.5,max(0.,onset/(prior+1e-8)-1.))
                        onbeat=abs(grid[row[begin]]-round(grid[row[begin]]))<.001
                        score=best[begin]+.65*accent+(.12 if onbeat else 0)-.28
                        if score>best[end]:best[end]=score;parts[end]=(begin,row[begin:end])
                if parts[length] is None:clipped.append(row)
                else:
                    split=[];cursor=length
                    while cursor:
                        begin,chunk=parts[cursor];split.append(chunk);cursor=begin
                    clipped.extend(reversed(split))
            if clipped:
                budget=1 if quiet else (2 if load<.5 else (len(clipped) if hard else 3))
                if melody:budget=1 if load<.33 else 2 if load<.55 else 3
                strongest=sorted(clipped,key=lambda row:sum(lead[i] for i in row)/np.sqrt(len(row)),reverse=True)[:budget]
                clipped=sorted(strongest,key=lambda row:row[0])
            # Repeat the hand shape of strongly similar source phrases only
            # when their actual selected rhythms are the same.
            rhythm=tuple(round(float(grid[i]-start),2) for row in clipped for i in row)
            profile=np.stack((bass[idx],mid[idx]),axis=1).ravel()
            profile=profile/(np.linalg.norm(profile)+1e-9)
            reuse=None
            for prev in reversed(phrase_patterns):
                if prev['rhythm']==rhythm and prev['voice']==voice and len(prev['profile'])==len(profile) and float(np.dot(profile,prev['profile']))>.94:
                    reuse=prev['lanes'];recalled+=1;break
            lanes=[];lastlane=groups[-1]['lane'] if groups else 1
            for r,row in enumerate(clipped):
                low_sum=float(np.sum(bass[row]));mid_sum=float(np.sum(mid[row]))
                natural=0 if low_sum>mid_sum*1.12 else 1
                if reuse is not None and r<len(reuse):lane=reuse[r]
                elif voice=='bass':lane=0
                elif voice=='drums' and natural!=lastlane:lane=natural
                elif r and grid[row[0]]-grid[clipped[r-1][-1]]<=.5:
                    # A long dense stream is phrased as short hand groups.
                    lane=1-lastlane
                elif voice in ('response','harmony'):
                    lane=0 if grid[row[0]]-start<4 else 1
                    if len(row)==1:lane=natural
                else:lane=natural
                lanes.append(lane);lastlane=lane
                groups.append({'start_beat':float(grid[row[0]]),'end_beat':float(grid[row[-1]]),
                    'lane':lane,'beats':[float(grid[i]) for i in row],
                    'mean_source':round(float(np.mean(lead[row])),4),'section':sec['type']})
                for i in row:
                    notes.append({'time':round(float(times[i]),6),'lane':lane,'kind':'tap','section':region(grid[i])['type']})
            phrase_patterns.append({'rhythm':rhythm,'voice':voice,'profile':profile,'lanes':lanes})

        # Candidate holds are measured independently in low/upper harmonic
        # bands. This permits staggered/together two-lane sustains, which the
        # previous global exclusion rule prevented altogether.
        candidates=[]
        for lane in (0,1):
            chroma,henergy,change=tonal[lane]
            for i in range(0,len(grid)-8,2):
                b=grid[i];sec=region(b)
                if times[i]<3 or sec.get('focus')=='bass':continue
                if strength[i]<.8 or henergy[i]<float(np.quantile(henergy,.25)):continue
                reference=chroma[min(i+1,len(grid)-1)]
                maxlen=6 if melody else 4
                end=i
                for j in range(i+2,min(i+int(maxlen*4)+1,len(grid)),2):
                    if region(grid[j])['type']!=sec['type']:break
                    similarity=float(np.dot(reference,chroma[j])/(np.linalg.norm(reference)*np.linalg.norm(chroma[j])+1e-9))
                    if similarity<(.86 if lane==1 else .89) or henergy[j]<henergy[i]*.57 or energy[j]<energy[i]*.50:break
                    end=j
                length=float(grid[end]-b)
                if length*beat<.55 or times[end]>duration-2.5:continue
                rank=length*min(float(strength[i]),3)*(1.3 if sec.get('focus')=='harmony' else .8)
                candidates.append((rank,i,end,lane))
        holds=[]
        cap=round(duration/(11 if melody else 7.5))
        for rank,i,end,lane in sorted(candidates,reverse=True):
            if len(holds)>=cap:break
            a,b=float(grid[i]),float(grid[end])
            if any(h['lane']==lane and a<h['end']+1.5 and b>h['start']-1.5 for h in holds):continue
            # Keep sustained gestures distributed, while allowing the other
            # band to start inside the first hold, as in the reference clips.
            if any(h['lane']!=lane and abs(a-h['start'])<2 and (b<h['start'] or a>h['end']) for h in holds):continue
            holds.append({'start':a,'end':b,'lane':lane,'source_rank':round(rank,4)})
        holdguard=max(.16,beat*(.25 if hard else .5))
        for h in holds:
            t,e=phase+h['start']*beat,phase+h['end']*beat
            notes=[n for n in notes if not(n['lane']==h['lane'] and t-holdguard< n['time'] <e+holdguard)]
            notes.append({'time':round(t,6),'end_time':round(e,6),'length_beats':h['end']-h['start'],
                'lane':h['lane'],'kind':'hold','section':region(h['start'])['type']})

        # A few percussive fills become independent mashers. Their required
        # count is our game's rule; reference HITS feedback is not a threshold.
        rollcandidates=[]
        if not melody:
            for i in range(0,len(grid)-8,4):
                b=grid[i];sec=region(b)
                if b<24 or b%8<5 or sec.get('load',0)<.7:continue
                row=np.arange(i,i+8)
                if np.count_nonzero(strength[row]>1.1)<5:continue
                if any(h['start']-1<=b+2 and b<=h['end']+1 for h in holds):continue
                rollcandidates.append((float(np.mean(high[row]+mid[row])),float(b)))
        rolls=[]
        for rank,b in sorted(rollcandidates,reverse=True):
            if len(rolls)>=(3 if hard else 2):break
            if any(abs(b-r['beat'])<48 for r in rolls):continue
            length=2.;t,e=phase+b*beat,phase+(b+length)*beat
            notes=[n for n in notes if not t-holdguard<n['time']<e+holdguard]
            lane=0 if sid=='lost_one' else 1
            hits=max(4,min(10,round((e-t)*(7 if hard else 5))))
            notes.append({'time':round(t,6),'end_time':round(e,6),'length_beats':length,
                'lane':lane,'kind':'roll','required_hits':hits,'section':region(b)['type']})
            rolls.append({'beat':b,'length':length,'required_hits':hits})
        # Sparse two-source accents. Adjacent taps are cleared so double
        # accents do not turn every phrase into a jack immediately afterward.
        doubles=[]
        for i in sorted(range(0,len(grid),4),key=lambda i:min(bass[i],mid[i]),reverse=True):
            b,t=float(grid[i]),round(float(times[i]),6)
            if region(b).get('load',0)<.65 or min(bass[i],mid[i])<2.0:continue
            if any(abs(b-a)<(8 if hard else 16) for a in doubles):continue
            if not any(n['time']==t and n['kind']=='tap' for n in notes):continue
            if any(n['kind']!='tap' and n['time']-holdguard<=t<=n['end_time']+holdguard for n in notes):continue
            notes=[n for n in notes if abs(n['time']-t)>=beat*.5-.00001]
            notes.extend({'time':t,'lane':lane,'kind':'tap','section':region(b)['type'],'accent':True} for lane in (0,1))
            doubles.append(b)
        notes.sort(key=lambda n:(n['time'],n['lane']))
        # Validate, do not silently discard broken/overlapping gestures.
        last=[-10.,-10.]
        for n in notes:
            assert n['time']>=2 and n['time']<duration-2,n
            minspace=beat*(.25 if hard else .5)
            assert n['time']-last[n['lane']]>=minspace-.00001,(sid,n,last)
            last[n['lane']]=n.get('end_time',n['time'])
        counts={k:sum(n['kind']==k for n in notes) for k in ('tap','hold','roll')}
        overlaps=sum(a['lane']!=b['lane'] and max(a['time'],b['time'])<min(a['end_time'],b['end_time'])
            for k,a in enumerate([n for n in notes if n['kind']=='hold'])
            for b in [n for n in notes if n['kind']=='hold'][k+1:])
        interactions=sum(any(n['kind']=='tap' and n['lane']!=h['lane'] and h['time']<n['time']<h['end_time'] for n in notes)
            for h in notes if h['kind']=='hold')
        info.update(chart_revision='0.9.0',note_count=len(notes),note_types=counts,
            required_presses=sum(n.get('required_hits',1) for n in notes),double_accents=len(doubles),
            peak_objects_per_second=max(sum(a['time']<=n['time']<a['time']+1 for n in notes) for a in notes),
            overlapping_hold_pairs=int(overlaps),hold_tap_interactions=int(interactions),
            repeated_source_phrases=recalled,
            chart_status='参考三段本地视频的短组、持续交接与留白方式修订；选点由本曲音频候选支持，待真人同步试听验收')
        pending.extend(((chartpath,notes),(infopath,info)))
        key=chartpath.relative_to(game).as_posix()
        audit={'chart':key,'groups':groups,'holds':holds,'rolls':rolls,
            'recalled_source_phrases':recalled,'overlapping_hold_pairs':overlaps,'hold_tap_interactions':interactions}
        dump(local/'chart-audit-v09'/(key.replace('/','_')+'.json'),audit)
        report={'chart':key,'title':info['title'],'difficulty':chart_entry['label'],
            'old_count':len(old),'new_count':len(notes),'types':counts,'double_accents':len(doubles),
            'overlapping_hold_pairs':overlaps,'hold_tap_interactions':interactions,
            'peak_objects_per_second':info['peak_objects_per_second'],'repeated_source_phrases':recalled}
        reports.append(report)
        print(json.dumps(report,ensure_ascii=False),flush=True)
# All five arrangements must pass validation before project data is changed.
for path,data in pending:
    dump(path,data)
dump(local/'chart-audit-v09/report.json',reports)
