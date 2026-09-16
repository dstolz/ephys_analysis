function applyConfigToProject(obj, P)
    % Push shared run config (python/conda/output + SpikeInterface
    % preprocessing) into a project so it propagates to every dataset.
    if nargin < 2 || isempty(P); P = obj.Project; end
    if isempty(P); return; end
    P.PythonExe  = string(obj.PythonExeField.Value);
    P.CondaEnv   = string(obj.CondaEnvField.Value);
    P.OutputRoot = string(obj.OutputRootField.Value);
    sicfg = obj.gatherSIConfig();
    % Set fields directly (NOT pushConfig) so per-dataset ProbeFile
    % assignments made on the Probe tab are preserved.
    for k = 1:P.NumDatasets
        d = P.Datasets(k);
        d.PythonExe = P.PythonExe;
        d.CondaEnv  = P.CondaEnv;
        d.SIConfig  = sicfg;
        if P.OutputRoot ~= ""
            d.OutputDir = fullfile(P.OutputRoot, d.Name);
        end
    end
end
