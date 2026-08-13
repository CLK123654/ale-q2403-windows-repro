function run_cache_fill_glm(inputRoot,outputRoot)
resultsRoot = fullfile(outputRoot,"results");
if isfolder(resultsRoot), rmdir(resultsRoot,"s"); end
C = jsondecode(fileread(fullfile(inputRoot,"model_contract.json")));
T = readtable(fullfile(inputRoot,"cache_fill_bins.csv"),"VariableNamingRule","preserve");
required = string(C.required_columns(:))';
assert(isequal(string(T.Properties.VariableNames),required),"输入列或顺序不符合合同");
dt = C.bin_width_seconds;
n = height(T);
assert(n==C.bin_count && isequal(T.bin_id,(1:n)'),"bin_id或行数不符合合同");
assert(all(isfinite(T.time_seconds)) && max(abs(T.time_seconds-T.bin_id*dt))<=1e-12, ...
    "time_seconds不符合固定网格");
assert(all(isfinite(T.cache_pressure)),"cache_pressure包含非有限值");
y = T.dispatch_event;
assert(all(y==0 | y==1) && sum(y)==C.event_count,"dispatch_event不是合同约定的二值事件流");
assert(numel(C.forward_folds)==3,"前向折数量不符合合同");
previousTestEnd = [];
for f = 1:3
    fold = C.forward_folds(f);
    assert(fold.fold==f && fold.test_start_bin==fold.train_end_bin+1 && ...
        fold.test_end_bin-fold.test_start_bin+1==800 && fold.test_end_bin<=n, ...
        "前向折边界不连续");
    if ~isempty(previousTestEnd), assert(fold.train_end_bin==previousTestEnd,"训练前缀未承接上一测试边界"); end
    previousTestEnd = fold.test_end_bin;
end
assert(previousTestEnd==n,"最后一个测试段未覆盖观测终点");

[X,names] = build_dispatch_design(T.cache_pressure,y);
expectedH1 = [0;y(1:end-1)];
expectedH2 = zeros(n,1); expectedH3 = zeros(n,1);
for i = 1:n
    expectedH2(i) = sum(y(max(1,i-6):max(0,i-2)));
    expectedH3(i) = sum(y(max(1,i-16):max(0,i-7)));
end
assert(isequal(X(:,3),expectedH1) && isequal(X(:,4),expectedH2) && isequal(X(:,5),expectedH3), ...
    "调度历史矩阵包含当前或未来事件");

modelNames = ["M0","M1","M2"]; widths = [1,2,5];
assert(isequal(string(C.models.M0(:))',names(1)) && ...
    isequal(string(C.models.M1(:))',names(1:2)) && ...
    isequal(string(C.models.M2(:))',names),"模型特征集合不符合合同");
foldRows = cell(0,9);
meanDev = zeros(3,1);
allConverged = true;
for m = 1:3
    Xm = X(:,1:widths(m));
    dev = zeros(3,1);
    for f = 1:3
        fold = C.forward_folds(f);
        trainEnd = fold.train_end_bin;
        testStart = fold.test_start_bin;
        testEnd = fold.test_end_bin;
        [b,it,ok] = fit_poisson_irls(Xm(1:trainEnd,:),y(1:trainEnd),dt, ...
            C.ridge_lambda,C.irls_max_iterations,C.irls_tolerance,C.eta_clip);
        allConverged = allConverged && ok;
        muTest = exp(min(max(Xm(testStart:testEnd,:)*b+log(dt),C.eta_clip(1)),C.eta_clip(2)));
        dev(f) = poisson_deviance(y(testStart:testEnd),muTest);
        convergedText = "false";
        if ok, convergedText = "true"; end
        foldRows(end+1,:) = {modelNames(m),f,trainEnd,testStart,testEnd, ...
            sum(y(testStart:testEnd)),dev(f),it,convergedText}; %#ok<AGROW>
    end
    meanDev(m) = mean(dev);
end
foldMetrics = cell2table(foldRows,'VariableNames', ...
    ["model","fold","train_end_bin","test_start_bin","test_end_bin","test_events", ...
     "holdout_deviance","irls_iterations","converged"]);
[sortedDev,order] = sort(meanDev);
assert(sortedDev(2)-sortedDev(1)>C.selection_tie_tolerance,"最优模型不唯一");
summary = table(modelNames(order)',widths(order)',sortedDev,(1:3)',string((1:3)'==1), ...
    'VariableNames',["model","feature_count","mean_holdout_deviance","rank","selected"]);
selected = summary.model(1);
selectedWidth = widths(modelNames==selected);
[beta,~,fullConverged] = fit_poisson_irls(X(:,1:selectedWidth),y,dt, ...
    C.ridge_lambda,C.irls_max_iterations,C.irls_tolerance,C.eta_clip);
coefficients = table(repmat(selected,selectedWidth,1),names(1:selectedWidth)',beta, ...
    ["false";repmat("true",selectedWidth-1,1)], ...
    'VariableNames',["model","feature","coefficient","penalized"]);
mu = exp(min(max(X(:,1:selectedWidth)*beta+log(dt),C.eta_clip(1)),C.eta_clip(2)));
rescaled = rescale_dispatch_events(y,mu);
z = sort(rescaled.z_uniform);
eventCount = numel(z);
ksD = max([max((1:eventCount)'/eventCount-z),max(z-(0:eventCount-1)'/eventCount)]);
ksBound = C.time_rescaling_ks_constant/sqrt(eventCount);
ks = table(selected,eventCount,ksD,ksBound,string(ksD<=ksBound),mean(z), ...
    'VariableNames',["selected_model","event_count","ks_d","ks_bound_95","ks_pass","mean_z"]);

assert(allConverged && fullConverged,"IRLS拟合未收敛");
if ~isfolder(resultsRoot), mkdir(resultsRoot); end
writetable(foldMetrics,fullfile(resultsRoot,"fold_metrics.csv"));
writetable(summary,fullfile(resultsRoot,"model_summary.csv"));
writetable(coefficients,fullfile(resultsRoot,"selected_coefficients.csv"));
writetable(rescaled,fullfile(resultsRoot,"rescaled_dispatches.csv"));
writetable(ks,fullfile(resultsRoot,"ks_diagnostic.csv"));
review = sprintf(char(join(["#边缘缓存填充请求预测评估";""; ...
    "所选模型：%s";"";"平均前向留出deviance：%.6f";"";"填充请求数：%d";""; ...
    "时间缩放KS统计量：%.6f";"";"95%%边界：%.6f";""; ...
    "本批结果说明缓存压力和近期填充请求记录能够改善后续请求预测。容量组将据此继续评估近期请求特征，策略调整仍结合后续线上试验。"],newline)), ...
    char(selected),summary.mean_holdout_deviance(1),eventCount,ksD,ksBound);
fid = fopen(fullfile(outputRoot,"PREDICTION_REVIEW.md"),"w");
assert(fid~=-1,"无法写入预测评估说明");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid,review,"char");
end
