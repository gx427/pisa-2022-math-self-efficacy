"""Draw the seven article figures from the supplied, unrounded plotting CSVs.

Run from the extracted resource directory:
    python revision/scripts/draw_figures.py
Dependencies: reportlab, pypdfium2, Pillow. Install Arial regular and bold
and supply --font-dir if they are not in the Windows system font directory.
"""
import argparse
import os
import csv
import math
from pathlib import Path
from collections import defaultdict

import pypdfium2 as pdfium
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

WIDTH = 174 / 25.4 * 72
# Match the native aspect ratios of the figures embedded in the manuscript.
HEIGHTS = [765, 737, 588, 673, 1261, 956, 552]
# Muted green and peach adapted from Yeager et al., Nature (2019), Fig. 2a,b.
INK, RULE = '#28312E', '#A7B1AB'
SYSTEMS = {'HKG': ('Hong Kong (China)', '#49685C'), 'TAP': ('Chinese Taipei', '#896155')}
FILLS = {'HKG':'#A4BDAF', 'TAP':'#F5BBAA'}
OFFSETS = {'HKG':5, 'TAP':-5}
VARIABLES = {'ANXMAT': 'Mathematics anxiety', 'ESCS': 'Socioeconomic status',
             'FAMSUP': 'Family support', 'RELATST': 'Student–teacher relationships'}


def text(c, x, y, value, size=8, align='left', bold=False):
    c.setFont('Arial-Bold' if bold else 'Arial', size)
    c.setFillColor(HexColor(INK))
    draw = {'left': c.drawString, 'right': c.drawRightString, 'center': c.drawCentredString}
    draw[align](x, y, value)


def line(c, x1, y1, x2, y2, color=INK, weight=.53, dashed=False):
    c.setLineWidth(weight)
    c.setStrokeColor(HexColor(color))
    c.setDash([2.3, 2] if dashed else [])
    c.line(x1, y1, x2, y2)


def marker(c, x, y, group):
    fill = FILLS.get(group, '#65706D')
    stroke = SYSTEMS[group][1] if group in SYSTEMS else INK
    c.setFillColor(HexColor(fill))
    c.setStrokeColor(HexColor(stroke))
    c.setDash([])
    c.setLineWidth(.8)
    if group == 'HKG':
        c.circle(x, y, 2.75, stroke=1, fill=1)
        return
    vertices = [(x,y+3.25),(x-3.05,y-2.35),(x+3.05,y-2.35)]
    if group not in SYSTEMS:
        vertices = [(x,y+2.75),(x-2.75,y),(x,y-2.75),(x+2.75,y)]
    path = c.beginPath()
    path.moveTo(*vertices[0])
    for xy in vertices[1:]:
        path.lineTo(*xy)
    path.close()
    c.drawPath(path,fill=1,stroke=1)


def legend(c, h, intervals=True):
    x = 20
    for group,(label,stroke) in SYSTEMS.items():
        if intervals:
            line(c,x-8,h-12,x+8,h-12,stroke,.85)
        marker(c,x,h-12,group)
        text(c,x+13,h-14.8,label,8.3)
        x += 104


def heading(c, x0, x1, y, title, letter=None, group=None):
    if group:
        marker(c,x0+4,y+3,group)
        x=x0+14
    elif letter:
        text(c,x0,y,letter,10.6,bold=True)
        x=x0+13
    else:
        x=x0
    text(c,x,y,title,8.7,bold=True)
    line(c,x0,y-5,x1,y-5,'#C3CAC6',.54)

def ticks(lo, hi, count=5):
    raw = (hi-lo) / (count-1)
    decade = 10 ** math.floor(math.log10(raw))
    step = min((m*decade for m in (1, 2, 2.5, 5, 10)), key=lambda s: abs(s-raw))
    return [round(i*step, 10) for i in range(math.ceil(lo/step-1e-8), math.floor(hi/step+1e-8)+1)]


def fmt(value):
    return f'{value:g}'.replace('-', '−')


def point_panel(c, rows, box, labels, label_key, domain, *, value='estimate',
                intervals=True, show_labels=True, zero=True, ticks_at=None, paired=True,
                label_terms=()):
    x0, y0, x1, y1 = box
    lo, hi = domain
    convert = lambda v: x0+(float(v)-lo)/(hi-lo)*(x1-x0)
    if zero and lo < 0 < hi:
        line(c, convert(0), y0, convert(0), y1, RULE, .55, True)
    line(c, x0, y0, x1, y0)
    for t in ticks_at if ticks_at is not None else ticks(lo,hi):
        x = convert(t)
        line(c, x, y0, x, y0-3)
        text(c, x, y0-13, fmt(t), 7.6, 'center')
    pitch = (y1-y0)/len(labels)
    centers = {label:y1-(i+.5)*pitch for i,label in enumerate(labels)}
    if show_labels:
        for label,y in centers.items():
            text(c,9,y-2.8,label,8.2)
    for r in rows:
        group = r['economy']
        color = SYSTEMS[group][1] if group in SYSTEMS else INK
        y = centers[r[label_key]] + (OFFSETS.get(group,0) if paired else 0)
        val = float(r[value])
        assert lo <= val <= hi
        if intervals:
            a,b = float(r['lower']),float(r['upper'])
            assert lo <= a <= val <= b <= hi
            a,b = convert(a),convert(b)
            line(c,a,y,b,y,color,.84)
            for x in (a,b):
                line(c,x,y-2,x,y+2,color,.72)
        marker(c,convert(val),y,group)
        if r.get('variable') in label_terms:
            text(c,convert(r['upper'])+4,y-2.3,decimal(val,3),7.1)


def traces(c, rows, h):
    cells = defaultdict(list)
    for r in rows:
        cells[r['variable'],r['economy'],int(r['chain'])].append((int(r['iteration']),float(r['mean'])))
    left, right, gap = 59, WIDTH-13, 24
    w = (right-left-gap)/2
    for j,(group,(label,color)) in enumerate(SYSTEMS.items()):
        x=left+j*(w+gap)
        heading(c,x,x+w,h-12,f'{label} ({group})',group=group)
    ordered=['ANXMAT','ESCS','FAMSUP','RELATST']
    row_height=(h-55)/4
    for i,var in enumerate(ordered):
        top=h-34-i*row_height
        bottom=top-row_height+23
        vals=[v for (k,_,_),pts in cells.items() if k==var for _,v in pts]
        span=max(vals)-min(vals)
        lo,hi=min(vals)-span*.08,max(vals)+span*.08
        text(c,left,top+4,f'{VARIABLES[var]} ({var})',8.3,bold=True)
        for j,(group,(_,color)) in enumerate(SYSTEMS.items()):
            x=left+j*(w+gap)
            line(c,x,bottom,x,top)
            line(c,x,bottom,x+w,bottom)
            for t in ticks(lo,hi,4):
                y=bottom+(t-lo)/(hi-lo)*(top-bottom)
                line(c,x-2.5,y,x,y)
                if j==0: text(c,x-5,y-2.5,fmt(t),7.2,'right')
            for t in (1,4,7,10):
                xx=x+(t-1)*w/9
                line(c,xx,bottom,xx,bottom-2.5)
                if i==3: text(c,xx,bottom-12,str(t),7.5,'center')
            c.saveState()
            c.setStrokeColor(HexColor(color))
            c.setStrokeAlpha(.54)
            c.setLineWidth(.62)
            for chain in range(1,21):
                pts=sorted(cells[var,group,chain])
                assert [t for t,_ in pts]==list(range(1,11))
                path=c.beginPath()
                for k,(t,v) in enumerate(pts):
                    xy=(x+(t-1)*w/9,bottom+(v-lo)/(hi-lo)*(top-bottom))
                    (path.moveTo if k==0 else path.lineTo)(*xy)
                c.drawPath(path)
            c.restoreState()
    c.saveState()
    c.translate(12,h/2)
    c.rotate(90)
    text(c,0,0,'Mean of imputed values',8.2,'center')
    c.restoreState()
    text(c,(left+right)/2,10,'Imputation iteration',8.2,'center')


def prediction(c, rows, h):
    legend(c,h,intervals=False)
    x0,x1,y0,y1=57,WIDTH-14,38,h-32
    line(c,x0,y0,x0,y1)
    line(c,x0,y0,x1,y0)
    convert=lambda v:y0+(y1-y0)*float(v)/.4
    for v in (0,.1,.2,.3,.4):
        y=convert(v)
        line(c,x0-3,y,x0,y)
        text(c,x0-7,y-2.5,fmt(v),7.6,'right')
    models=['Support model','Full linear model','Full spline model']
    for i,label in enumerate(models):
        x=x0+(i+.5)*(x1-x0)/3
        text(c,x,y0-15,label,8.2,'center')
        for r in (r for r in rows if r['model']==label):
            group=r['economy']
            pos=x+(-15 if group=='HKG' else 15)
            y=convert(r['R2'])
            marker(c,pos,y,group)
            text(c,pos,y+7,decimal(r['R2'],3),7.7,'center')
    c.saveState()
    c.translate(15,(y0+y1)/2)
    c.rotate(90)
    text(c,0,0,'Weighted held-out R² (five-fold validation)',8.5,'center')
    c.restoreState()


def decimal(value, places):
    return f'{float(value):.{places}f}'.replace('-', '−')


def draw(c, n, rows, h):
    if n==5:
        traces(c,rows,h)
        return
    if n==7:
        prediction(c,rows,h)
        return
    labels=list(dict.fromkeys(r.get('label') for r in rows))
    right=WIDTH-12
    left=135
    bottom=32
    if n in (2,3,6):
        legend(c,h)
    if n in (1,2):
        gap=20
        width=(right-left-gap)/2
        for j in (0,1):
            x=left+j*(width+gap)
            if n==1:
                group=list(SYSTEMS)[j]
                subset=[r for r in rows if r['economy']==group]
                y=h-16
                heading(c,x,x+width,y,SYSTEMS[group][0],group=group)
                domain=(-.6,.4)
                xt=[-.4,0,.4]
            else:
                model=('a  Support model','b  Full model')[j]
                subset=[r for r in rows if r['model']==model]
                y=h-36
                heading(c,x,x+width,y,model[3:],letter=model[0])
                domain=(-.52,.56)
                xt=[-.5,-.25,0,.25,.5]
            point_panel(c,subset,(x,bottom,x+width,y-11),labels,'label',domain,
                        value='mean' if n==1 else 'estimate',show_labels=j==0,
                        paired=n==2,ticks_at=xt,label_terms=('FAMSUP','RELATST') if n==2 else ())
    elif n in (3,4):
        left=159 if n==3 else 130
        plot_end=WIDTH-125
        ytop=h-(37 if n==3 else 18)
        heading(c,9,left-10,ytop,'Path' if n==3 else 'Predictor')
        heading(c,left,plot_end,ytop,'Coefficient product' if n==3 else 'Coefficient difference')
        heading(c,plot_end+14,right,ytop,'Estimate [95% CI]')
        box=(left,bottom,plot_end,ytop-11)
        domain=(-.014,.087) if n==3 else (-.31,.12)
        point_panel(c,rows,box,labels,'label',domain,show_labels=False,paired=n==3,
                    ticks_at=[0,.02,.04,.06,.08] if n==3 else [-.3,-.2,-.1,0,.1])
        step=(box[3]-bottom)/len(labels)
        for i,label in enumerate(labels):
            center=box[3]-(i+.5)*step
            if n==3:
                first,mid,last=label.split(' → ')
                text(c,9,center+3,first,8.3,bold=True)
                text(c,9,center-8,'→ '+mid+' → '+last,7.8)
            else:
                text(c,9,center-2.7,label,8.3)
            for r in (r for r in rows if r['label']==label):
                offset=OFFSETS.get(r['economy'],0) if n==3 else 0
                y=center+offset
                if n==3: marker(c,plot_end+18,y,r['economy'])
                places=3 if n==3 else 2
                estimate=decimal(r['estimate'],places)
                limits=', '.join(decimal(r[k],places) for k in ('lower','upper'))
                text(c,plot_end+(28 if n==3 else 14),y-2.5,f'{estimate} [{limits}]',7.55)
            if i<len(labels)-1:
                yline=center-step/2
                line(c,9,yline,left-11,yline,'#DADEDC',.42)
                line(c,plot_end+14,yline,right,yline,'#DADEDC',.42)
        if n==4:
            text(c,WIDTH/2,6,'Hong Kong (China) minus Chinese Taipei',8.3,'center')
        return
    elif n==6:
        left=94
        width=(right-left-21)/2
        groups=['Socioeconomic status','Proactive study behaviour','Mathematics anxiety','Student–teacher relationships']
        mid=(h+25)/2
        for j,name in enumerate(groups):
            x=left+(j%2)*(width+21)
            top,y0=(h-43,mid+16) if j<2 else (mid-30,bottom)
            heading(c,x,x+width,top+9,name)
            subset=[r for r in rows if r['variable']==name]
            lo=min(0,min(float(r['lower']) for r in subset))
            hi=max(0,max(float(r['upper']) for r in subset))
            pad=(hi-lo)*.10
            point_panel(c,subset,(x,y0,x+width,top),['School fixed effects','Complete case','20 imputations'],
                        'analysis',(lo-pad,hi+pad),show_labels=j%2==0)
    axis='Weighted index mean' if n==1 else 'Unstandardised coefficient'
    text(c,(left+right)/2,6,axis+' (95% CI)',8.4,'center')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data',type=Path,default=Path('reference/figure_data'))
    parser.add_argument('--out',type=Path,default=Path('revision/figures'))
    parser.add_argument('--font-dir',type=Path,default=Path(os.environ.get('APER_FONT_DIR', 'C:/Windows/Fonts')))
    args=parser.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    for font,filename in [('Arial','arial.ttf'),('Arial-Bold','arialbd.ttf')]:
        pdfmetrics.registerFont(TTFont(font,str(args.font_dir/filename)))
    for n in range(1,8):
        source,=args.data.glob(f'Figure_{n}_*.csv')
        with source.open(encoding='utf-8-sig',newline='') as f:
            rows=list(csv.DictReader(f))
        assert len(rows)==[14,18,6,6,1600,24,6][n-1]
        stem=args.out/f'Fig{n}'
        height=WIDTH*HEIGHTS[n-1]/1275
        canvas=Canvas(str(stem.with_suffix('.pdf')),pagesize=(WIDTH,height),invariant=1)
        canvas.setTitle(source.stem.replace('_',' '))
        draw(canvas,n,rows,height)
        canvas.showPage()
        canvas.save()
        with pdfium.PdfDocument(str(stem.with_suffix('.pdf'))) as pdf:
            bitmap=pdf[0].render(scale=600/72)
            image=bitmap.to_pil().convert('RGB')
            image.save(stem.with_suffix('.png'),dpi=(600,600))
            image.save(stem.with_suffix('.tiff'),dpi=(600,600),compression='tiff_lzw')
        print(stem,image.size)


if __name__=='__main__':
    main()
