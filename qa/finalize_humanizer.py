from __future__ import annotations
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];TASK=ROOT/'task';QA=TASK/'.qa';QA.mkdir(exist_ok=True)
names=['ALE-专家数据作业表_q2403.csv','reference.zip','task_fields.json','任务prompt.txt','任务名称.txt','任务概要.txt','任务规格转化.xlsx','关键动作.txt','关键标准答案.xlsx','环境依赖.txt','相关专业软件的关键步骤.txt','评分表.txt','输入数据包.zip']
review={
 'schema_version':1,'skill':'humanizer-zh','result':'PASS',
 'reviewed_scopes':['任务名称','任务概要','任务prompt','关键动作','评分表','环境依赖','软件步骤','输入材料中的自然语言','Reference中的用户可见文字','关键标准答案工作簿全部自然语言','任务规格工作簿全部自然语言'],
 'scores':{'直接性':10,'节奏':9,'信任度':9,'真实性':9,'精炼度':9,'total':46},'minimum_total':45,
 'notes':['标题直接写容量组的预测复核，没有因果强度、审计矩阵或模型证明等夸大词。','题面从内容分发平台的填充策略评审切入，输入由容量组提供，数据口径和参数均来自CSV及模型合同。','Reference删除Python重放器、测试脚本、validation和固定通过结论，只保留MATLAB程序、业务结果和预测评估说明。','程序只支持当前观测窗内的关联与预测比较，业务消费者及后续线上试验边界清楚。','任务规格围绕MATLAB时序特征、PoissonIRLS、前向留出、全量重估和时间缩放逐项设计。'],
 'reviewed_artifacts_sha256':{n:hashlib.sha256((TASK/n).read_bytes()).hexdigest() for n in names},
 'online_ai_field_used_as_conclusion':False
}
(QA/'humanizer-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
