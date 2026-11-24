"""Write the four article tables and fifteen supplementary tables as CSV files."""
from pathlib import Path
import argparse
import csv
import re

args=argparse.ArgumentParser(description=__doc__)
args.add_argument('--computed', action='store_true', help='Use the locally recomputed estimates.')
opts=args.parse_args()
result_dir=Path('revision/results' if opts.computed else 'reference/results')
output=Path('revision/tables')
output.mkdir(parents=True,exist_ok=True)
def data(name):
    with (result_dir/(name+'.csv')).open(encoding='utf-8-sig',newline='') as stream:
        return list(csv.DictReader(stream))
# Presentation labels and notes are independent of the numerical estimates.
import json
layout=json.loads(Path('reference/table_layout.json').read_text(encoding='utf-8'))
def table(caption,headers,rows):
    number=re.search(r'^Table (S?\d+[a-g]?)\.',caption)[1]
    presentation=layout[number]
    index_labels=presentation['row_labels']
    if len(rows)!=len(index_labels):
        raise ValueError('Unexpected row count for table '+number)
    displayed=[]
    for i,(row,labels_here) in enumerate(zip(rows,index_labels)):
        row=list(row)
        row[:len(labels_here)]=labels_here
        if number=='1' and i<4:
            row[1:3]=[f'{int(x):,}' for x in row[1:3]]
        if number=='4':
            row[2:]=[x[1:] if x.startswith('0.') else x for x in row[2:]]
        displayed.append(row)
    with (output/('Table_'+number+'.csv')).open('w',encoding='utf-8',newline='') as stream:
        writer=csv.writer(stream)
        writer.writerow(presentation['headers'])
        writer.writerows(displayed)
def num(x, d=3):
    try:
        return f'{float(x):.{d}f}'.replace('-', '−')
    except:
        return '—'

def ci(r, d=3, key='estimate'):
    return f"{num(r[key], d)} [{num(r['lower'], d)}, {num(r['upper'], d)}]"

def pval(x):
    return '< .001' if float(x) < 0.001 else num(x, 3)
labels = {'MATHEFF': 'Mathematics self-efficacy', 'ESCS': 'Socioeconomic status', 'FAMSUP': 'Family support', 'RELATST': 'Teacher relationships', 'MATHPERS': 'Proactive study behaviour', 'ANXMAT': 'Mathematics anxiety', 'BELONG': 'School belonging', 'FEMALE': 'Female (vs male)', 'GRADE': 'Relative grade', 'MATH': 'Mathematics achievement'}
des = data('descriptive')
flow = data('sample_flow')
means = data('mean_differences')
mods = data('model_estimates')
cons = data('economy_contrasts')
get = lambda rs, **kw: next((r for r in rs if all((r[k] == v for k, v in kw.items()))))
rows = []
for field, lab in [('n', 'Sampled students'), ('schools', 'Sampled schools'), ('outcome_observed', 'Observed efficacy'), ('complete_case', 'Complete cases')]:
    rows.append([lab, get(flow, economy='HKG')[field], get(flow, economy='TAP')[field], '—'])
for v in ['MATHEFF', 'ESCS', 'FAMSUP', 'RELATST', 'MATHPERS', 'ANXMAT', 'BELONG', 'MATH']:
    hh = get(des, economy='HKG', variable=v)
    tt = get(des, economy='TAP', variable=v)
    dd = get(means, variable=v)
    rows.append([labels[v], ci(hh, 1 if v == 'MATH' else 3, 'mean'), ci(tt, 1 if v == 'MATH' else 3, 'mean'), ci(dd, 1 if v == 'MATH' else 3, 'difference_HKG_minus_TAP')])
table('Table 1. Sample size and weighted descriptive profiles', ['Measure', 'Hong Kong (China)\nMean [95% CI]', 'Chinese Taipei\nMean [95% CI]', 'HKG − TAP'], rows)
rows = []
for v in ['ESCS', 'FAMSUP', 'RELATST', 'MATHPERS', 'ANXMAT', 'BELONG', 'FEMALE', 'GRADE']:
    row = [labels[v]]
    for g in ['HKG', 'TAP']:
        row.append(ci(get(mods, economy=g, analysis='Complete case', term='full:' + v)))
    rows.append(row)
table('Table 2. Full-model associations with mathematics self-efficacy', ['Predictor', 'Hong Kong (China)\nB [95% CI]', 'Chinese Taipei\nB [95% CI]'], rows)
rows = []
ilabs = {'ind_family_behaviour': 'Family support → behaviour → efficacy', 'ind_relationship_anxiety': 'Teacher relationships → anxiety → efficacy', 'ind_relationship_belonging': 'Teacher relationships → belonging → efficacy'}
for term, lab in ilabs.items():
    rows.append([lab, *[ci(get(mods, economy=g, analysis='Complete case', term=term)) for g in ['HKG', 'TAP']], ci(get(cons, analysis='Complete case', term=term))])
table('Table 3. Selected indirect associations', ['Specified sequence', 'Hong Kong (China)\nProduct [95% CI]', 'Chinese Taipei\nProduct [95% CI]', 'HKG − TAP\n[95% CI]'], rows)
rows = []
for v in ['ESCS', 'FAMSUP', 'RELATST', 'MATHPERS', 'ANXMAT', 'BELONG']:
    r = get(cons, analysis='Complete case', term='full:' + v)
    rows.append([labels[v], ci(r), pval(r['p']), pval(r['p_holm'])])
table('Table 4. Between-system full-model coefficient differences', ['Predictor', 'HKG − TAP [95% CI]', 'Raw p', 'Holm p'], rows)
rows = []
missing = data('missingness')
for v in labels:
    if v == 'MATH':
        continue
    a = get(missing, economy='HKG', variable=v)
    b = get(missing, economy='TAP', variable=v)
    rows.append([labels[v], a['n_missing'], num(a['pct_missing'], 2), num(a['weighted_pct'], 2), b['n_missing'], num(b['pct_missing'], 2), num(b['weighted_pct'], 2)])
table('Table S1. Missingness in the sampled students', ['Variable', 'HKG missing n', 'HKG %', 'HKG weighted %', 'TAP missing n', 'TAP %', 'TAP weighted %'], rows)
for k, prefix in enumerate(['support:', 'behaviour:', 'anxiety:', 'belonging:', 'family:', 'relationship:', 'ind_SES']):
    terms = [r['term'] for r in mods if r['economy'] == 'HKG' and r['analysis'] == 'Complete case' and r['term'].startswith(prefix)]
    rows = [[term, *[ci(get(mods, economy=g, analysis='Complete case', term=term), 5 if term.startswith('ind_') else 3) for g in ['HKG', 'TAP']]] for term in terms]
    table(f"Table S2{chr(97 + k)}. Equation-level results for {prefix.rstrip(':')}", ['Equation term', 'Hong Kong (China)\n' + ('Product' if prefix == 'ind_SES' else 'B') + ' [95% CI]', 'Chinese Taipei\n' + ('Product' if prefix == 'ind_SES' else 'B') + ' [95% CI]'], rows)
rows = []
for term in ['full:' + v for v in ['ESCS', 'FAMSUP', 'RELATST', 'MATHPERS', 'ANXMAT', 'BELONG', 'FEMALE', 'GRADE']] + list(ilabs):
    rows.append([term, *[ci(get(mods, economy=g, analysis='20 imputations', term=term), 5 if term.startswith('ind_') else 3) for g in ['HKG', 'TAP']]])
table('Table S3. Twenty-imputation sensitivity', ['Term', 'Hong Kong (China)\nEstimate [95% CI]', 'Chinese Taipei\nEstimate [95% CI]'], rows)
sens = data('sensitivity_models')
for si, spec in enumerate(['School fixed effects', 'Reasoning self-efficacy']):
    rows = []
    for v in ['ESCS', 'FAMSUP', 'RELATST', 'MATHPERS', 'ANXMAT', 'BELONG', 'FEMALE', 'GRADE']:
        rows.append([labels[v], *[ci(get(sens, economy=g, analysis=spec, term=v)) for g in ['HKG', 'TAP']]])
    table('Table S4' + chr(97 + si) + '. ' + spec, ['Predictor', 'Hong Kong (China)\nB [95% CI]', 'Chinese Taipei\nB [95% CI]'], rows)
fits = data('measurement_fit')
rows = [[r['scale'], r['model'], num(r['CFI']), num(r['TLI']), num(r['RMSEA']), num(r['SRMR'])] for r in fits]
table('Table S5. Ordinal measurement diagnostics', ['Scale', 'Constraints', 'CFI', 'TLI', 'RMSEA', 'SRMR'], rows)
rows = [[r['economy'], r['model'], r['n'], num(r['R2']), num(r['RMSE']), num(r['MAE'])] for r in data('school_validation')]
table('Table S6. School-separated five-fold validation', ['System', 'Model', 'n', 'R²', 'RMSE', 'MAE'], rows)
rows = []
for term in ['MATHEFF', 'ESCS', 'FEMALE', 'GRADE']:
    rows.append([labels[term], *[ci(get(mods, economy=g, analysis='Achievement 10 PV complete case', term=term), 2) for g in ['HKG', 'TAP']]])
table('Table S7. Mathematics achievement associations', ['Predictor', 'Hong Kong (China)\nPoints [95% CI]', 'Chinese Taipei\nPoints [95% CI]'], rows)

# The six coefficient products and three sets of intervals in Table S8.
paths=data('paths')
rows=[]
for predictor in ('FAMSUP','RELATST'):
    for correlate in ('MATHPERS','ANXMAT','BELONG'):
        row=[predictor,correlate]
        for system in ('HKG','TAP','HKG-TAP'):
            record=get(paths,predictor=predictor,correlate=correlate,system=system)
            row.append(ci(record,4).replace('−0.0000 ', '0.0000 ').replace('−0.000 ', '0.000 '))
        rows.append(row)
table('Table S8. Products of coefficients',[],rows)
with (output/'Captions_and_notes.csv').open('w',encoding='utf-8',newline='') as stream:
    writer=csv.writer(stream)
    writer.writerow(['Table','Caption','Note'])
    writer.writerows((k,v['caption'],v['note']) for k,v in layout.items())
