function applyConfigToProject(obj, P)
%applyConfigToProject  Push the working config's shared settings onto a project.
%   Thin wrapper over EphysPipeline.applyConfigToDatasets (per-dataset
%   manifest state such as ProbeFile is never touched). Not while a run is
%   under way: the datasets keep the settings it started with.
if nargin < 2 || isempty(P); P = obj.Project; end
if isempty(P) || obj.RunActive; return; end
EphysPipeline.applyConfigToDatasets(obj.Config, P);
end
