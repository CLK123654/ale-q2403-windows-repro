function generate_reference
repoRoot=string(fileparts(fileparts(mfilename("fullpath"))));
workRoot=fullfile(repoRoot,"reference-candidate");
if isfolder(workRoot),rmdir(workRoot,"s");end
mkdir(workRoot);unzip(fullfile(repoRoot,"task","输入数据包.zip"),workRoot);
outputRoot=fullfile(workRoot,"output");copyfile(fullfile(repoRoot,"implementation","template_output"),outputRoot);
addpath(fullfile(outputRoot,"matlab"));run_cache_fill_glm(fullfile(workRoot,"input_data"),outputRoot);rmpath(fullfile(outputRoot,"matlab"));
zip(fullfile(repoRoot,"reference-candidate.zip"),"output",workRoot);
fprintf("REFERENCE CANDIDATE READY\n");
end
