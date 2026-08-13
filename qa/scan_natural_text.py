from __future__ import annotations
import json,re,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];TASK=ROOT/'task'
items=[]
for p in TASK.glob('*.txt'):items.append((p.name,p.read_text(encoding='utf-8')))
with zipfile.ZipFile(TASK/'输入数据包.zip') as z:
    for n in z.namelist():
        if n.endswith(('.md','.txt')):items.append(('输入数据包.zip:'+n,z.read(n).decode('utf-8')))
with zipfile.ZipFile(TASK/'reference.zip') as z:
    for n in z.namelist():
        if n.endswith(('.md','.txt')):items.append(('reference.zip:'+n,z.read(n).decode('utf-8')))
patterns={
 '引号':r'[\"\'“”‘’「」『』《》〈〉`]',
 '中英空格':r'[\u4e00-\u9fff][ \t]+[A-Za-z]|[A-Za-z][ \t]+[\u4e00-\u9fff]',
 '中数空格':r'[\u4e00-\u9fff][ \t]+\d|\d[ \t]+[\u4e00-\u9fff]',
 '英数空格':r'[A-Za-z][ \t]+\d|\d[ \t]+[A-Za-z]',
 '制题过程':r'返修|去AI|改题|Windows复现|Windows验证|GitHub Actions|双净|动态变化|负例|哈希|回读|QA|测试器|验证器|虚构|自造|合成|样例|示例数据|测试数据|演练数据|判卷|PASS|FAIL|validation|replay|test_results'
}
issues=[]
for label,text in items:
    for kind,pat in patterns.items():
        for m in re.finditer(pat,text,re.I):issues.append({'source':label,'kind':kind,'match':m.group()})
print(json.dumps({'result':'PASS' if not issues else 'FAIL','issues':issues},ensure_ascii=False,indent=2))
raise SystemExit(1 if issues else 0)
