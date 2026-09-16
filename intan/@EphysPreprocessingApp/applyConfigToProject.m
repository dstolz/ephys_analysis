function applyConfigToProject(obj, P)
%applyConfigToProject  Push the working config's shared settings onto a project.
%   Thin wrapper over EphysPipeline.applyConfigToDatasets (per-dataset
%   manifest state such as ProbeFile is never touched).
if nargin < 2 || isempty(P); P = obj.Project; end
if isempty(P); return; end
EphysPipeline.applyConfigToDatasets(obj.Config, P);
end
