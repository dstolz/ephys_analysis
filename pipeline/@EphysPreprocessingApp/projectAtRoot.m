function tf = projectAtRoot(obj, root)
%projectAtRoot  Whether the scanned project is the one under ROOT.
%   True when a project is scanned and its Root is ROOT (compared as
%   EphysDataset.pathKey forms). Only then are the Project table's ticks a
%   config's dataset selection (gatherProjectSection); a run, a plan and a
%   step's targets refuse another project's datasets (buildPipeline), and
%   opening a config for another root drops the scanned project
%   (applyConfig).
tf = ~isempty(obj.Project) && obj.Project.Root ~= "" ...
    && EphysDataset.pathKey(obj.Project.Root) == EphysDataset.pathKey(strtrim(string(root)));
end
