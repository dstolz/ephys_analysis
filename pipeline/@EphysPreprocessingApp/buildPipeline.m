function pipe = buildPipeline(obj)
%buildPipeline  An EphysPipeline over the scanned project with the working config.
%   Errors (EphysPreprocessingApp:NoProject) before a scan.
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    error('EphysPreprocessingApp:NoProject', 'Scan a project root first (Project tab).');
end
obj.Config = obj.gatherConfig();
pipe = EphysPipeline(obj.Config, Project=obj.Project, Refresh=false);
pipe.LogFcn = @(m) obj.runLog("%s", m);
end
