function verify_q2403
repoRoot=string(fileparts(fileparts(mfilename("fullpath"))));taskRoot=fullfile(repoRoot,"task");workRoot=fullfile(repoRoot,"evidence","windows-work");
if isfolder(workRoot),rmdir(workRoot,"s");end
mkdir(workRoot);assert(ispc,"MATLAB未在Windows运行器执行");
expectedMembers=sort(["output/PREDICTION_REVIEW.md";"output/matlab/build_dispatch_design.m";"output/matlab/fit_poisson_irls.m";"output/matlab/poisson_deviance.m";"output/matlab/rescale_dispatch_events.m";"output/matlab/run_cache_fill_glm.m";"output/results/fold_metrics.csv";"output/results/ks_diagnostic.csv";"output/results/model_summary.csv";"output/results/rescaled_dispatches.csv";"output/results/selected_coefficients.csv"]);
names=["clean directory a with spaces","clean directory b with spaces"];
runs=repmat(struct("root_id","","output_started_without_results",false,"primary_software_executed",false,"process_runs",0,"input_unchanged",false,"reference_match",false,"return_code",1,"generated_paths",strings(0,1)),2,1);
for i=1:2,runs(i)=run_clean(taskRoot,repoRoot,workRoot,names(i),expectedMembers);end

baseline=readtable(fullfile(workRoot,names(1),"candidate","output","results","selected_coefficients.csv"),TextType="string");
variantRoot=fullfile(workRoot,"positive pressure change");mkdir(variantRoot);unzip(fullfile(taskRoot,"输入数据包.zip"),variantRoot);variantOutput=fullfile(variantRoot,"output");copyfile(fullfile(repoRoot,"implementation","template_output"),variantOutput);
bins=readtable(fullfile(variantRoot,"input_data","cache_fill_bins.csv"),TextType="string");bins.cache_pressure(100)=bins.cache_pressure(100)+0.1;writetable(bins,fullfile(variantRoot,"input_data","cache_fill_bins.csv"));
addpath(fullfile(variantOutput,"matlab"));run_cache_fill_glm(fullfile(variantRoot,"input_data"),variantOutput);rmpath(fullfile(variantOutput,"matlab"));variant=readtable(fullfile(variantOutput,"results","selected_coefficients.csv"),TextType="string");changed=any(abs(variant.coefficient-baseline.coefficient)>1e-12);assert(changed,"缓存压力变化未进入模型系数");

negativeRoot=fullfile(workRoot,"negative duplicate bin");mkdir(negativeRoot);unzip(fullfile(taskRoot,"输入数据包.zip"),negativeRoot);negativeOutput=fullfile(negativeRoot,"output");copyfile(fullfile(repoRoot,"implementation","template_output"),negativeOutput);
bins=readtable(fullfile(negativeRoot,"input_data","cache_fill_bins.csv"),TextType="string");bins.bin_id(2)=bins.bin_id(1);writetable(bins,fullfile(negativeRoot,"input_data","cache_fill_bins.csv"));
addpath(fullfile(negativeOutput,"matlab"));failed=false;try,run_cache_fill_glm(fullfile(negativeRoot,"input_data"),negativeOutput);catch,failed=true;end;rmpath(fullfile(negativeOutput,"matlab"));residue=count_files(fullfile(negativeOutput,"results"));assert(failed&&residue==0,"重复bin_id未停止交付");

[status,osValue]=system('powershell -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; Write-Output ($o.Caption + ''|'' + $o.Version)"');assert(status==0);
evidence=struct("schema_version",1,"result","PASS","task_slug","cache_fill_forecast_review","actual_os",strtrim(string(osValue)),"runner_image","windows-2025","matlab_version",string(version),"matlab_release",string(version("-release")),"computer",string(computer),"github_run_id",string(getenv("GITHUB_RUN_ID")),"commit_sha",string(getenv("GITHUB_SHA")),"attachment_sha256",jsondecode(fileread(fullfile(repoRoot,"qa","expected_hashes.json"))),"clean_room_runs",runs,"positive_mutation",struct("field","cache_fill_bins.row100.cache_pressure","behavior_changed",changed,"passed",true),"negative_case",struct("field","duplicate_bin_id","matlab_failed",failed,"result_file_count",residue,"passed",true),"reference_member_count",numel(expectedMembers),"reference_match",true);
write_json(fullfile(workRoot,"windows-summary.json"),evidence);fprintf("Q2403 WINDOWS MATLAB PASS\n");
end

function report=run_clean(taskRoot,repoRoot,workRoot,name,expectedMembers)
runRoot=fullfile(workRoot,name);mkdir(runRoot);unzip(fullfile(taskRoot,"输入数据包.zip"),runRoot);expectedRoot=fullfile(runRoot,"expected");mkdir(expectedRoot);unzip(fullfile(taskRoot,"reference.zip"),expectedRoot);
inputRoot=fullfile(runRoot,"input_data");outputRoot=fullfile(runRoot,"candidate","output");copyfile(fullfile(repoRoot,"implementation","template_output"),outputRoot);assert(~isfolder(fullfile(outputRoot,"results")));
before=input_snapshot(inputRoot);addpath(fullfile(outputRoot,"matlab"));run_cache_fill_glm(inputRoot,outputRoot);run_cache_fill_glm(inputRoot,outputRoot);rmpath(fullfile(outputRoot,"matlab"));assert(strcmp(before,input_snapshot(inputRoot)));
assert(isequal(tree_relative(fullfile(runRoot,"candidate"),outputRoot),expectedMembers));compare_reference(expectedRoot,fullfile(runRoot,"candidate"));
report=struct("root_id",name,"output_started_without_results",true,"primary_software_executed",true,"process_runs",2,"input_unchanged",true,"reference_match",true,"return_code",0,"generated_paths",expectedMembers);write_json(fullfile(workRoot,replace(name," ","-")+"-compare.json"),report);
end

function compare_reference(expectedRoot,candidateRoot)
expectedFiles=tree_relative(expectedRoot,expectedRoot);actualFiles=tree_relative(candidateRoot,candidateRoot);assert(isequal(expectedFiles,actualFiles));
for i=1:numel(expectedFiles),rel=expectedFiles(i);left=fullfile(expectedRoot,rel);right=fullfile(candidateRoot,rel);if endsWith(rel,".csv"),assert_table_close(left,right,1e-6);else,assert(strcmp(fileread(left),fileread(right)));end,end
end
function names=tree_relative(base,root),listing=dir(fullfile(root,"**","*"));listing=listing(~[listing.isdir]);names=strings(numel(listing),1);for i=1:numel(listing),absolute=string(fullfile(listing(i).folder,listing(i).name));names(i)=replace(extractAfter(absolute,string(base)+filesep),filesep,"/");end;names=sort(names);end
function snapshot=input_snapshot(root),files=tree_relative(root,root);parts=strings(numel(files),1);for i=1:numel(files),parts(i)=files(i)+newline+string(fileread(fullfile(root,files(i))));end;snapshot=join(parts,newline+"---"+newline);end
function assert_table_close(aPath,bPath,tol),a=readtable(aPath,TextType="string");b=readtable(bPath,TextType="string");assert(isequal(a.Properties.VariableNames,b.Properties.VariableNames)&&height(a)==height(b));keys=["model","fold","feature","event_sequence","selected_model"];sortKeys=strings(0);for k=keys,if ismember(k,string(a.Properties.VariableNames)),sortKeys(end+1)=k;end,end;if ~isempty(sortKeys),a=sortrows(a,cellstr(sortKeys));b=sortrows(b,cellstr(sortKeys));end;for i=1:width(a),x=a{:,i};y=b{:,i};if isnumeric(x)&&isnumeric(y),assert(isequal(isnan(x),isnan(y)));m=~isnan(x);assert(all(abs(x(m)-y(m))<=tol));else,assert(isequaln(string(x),string(y)));end,end,end
function count=count_files(root),if ~isfolder(root),count=0;return;end;listing=dir(fullfile(root,"**","*"));count=sum(~[listing.isdir]);end
function write_json(path,value),h=fopen(path,"w");assert(h>=0);cleanup=onCleanup(@()fclose(h));fwrite(h,jsonencode(value,PrettyPrint=true),"char");fwrite(h,newline,"char");clear cleanup;end
