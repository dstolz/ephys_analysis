function pipe = buildPipeline(obj)
%buildPipeline  An EphysPipeline over the scanned project with the working config.
%   The background Kilosort4 runs the monitor follows are its PriorRuns: the
%   ones still going and the queued ones (KSQueue, prepared but not
%   started), so a plan says their datasets are skipped and a run leaves
%   them alone. Errors before a scan (EphysPreprocessingApp:NoProject),
%   when the scanned project is not the one under the config's root
%   (EphysPreprocessingApp:OtherProject: the root was edited, or a config
%   for another root was opened, since the scan), on a text field that does
%   not parse (gatherConfig) and while a run is under way
%   (EphysPreprocessingApp:RunActive: building one pushes the config onto
%   the datasets the run is processing).
if obj.RunActive
    error('EphysPreprocessingApp:RunActive', 'Wait for the run to finish (or Cancel it) first.');
end
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    error('EphysPreprocessingApp:NoProject', 'Scan a project root first (Project tab).');
end
obj.Config = obj.gatherConfig();
if ~obj.projectAtRoot(obj.Config.Project.Root)
    error('EphysPreprocessingApp:OtherProject', ...
        'The datasets scanned are those under %s, not under the project root %s. Press Scan on the Project tab first.', ...
        obj.Project.Root, obj.Config.Project.Root);
end
pipe = EphysPipeline(obj.Config, Project=obj.Project, Refresh=false);
pipe.LogFcn = @(m) obj.runLog("%s", m);
runs = obj.KSRuns(~[obj.KSRuns.done]);
for q = obj.KSQueue
    runs(end+1) = EphysPipeline.sortRun(q.Name, q.prepared, Queued=true); %#ok<AGROW>
end
pipe.PriorRuns = runs;
end
