function file = ks4ParamsFile(probeFile)
%ks4ParamsFile  The Kilosort4 parameter file that belongs to a probe map.
%   FILE = EphysPipelineConfig.ks4ParamsFile(PROBEFILE) is <folder>/<name>.ks4.json
%   for the probe map <folder>/<name>.json (KS4ParamsSuffix). The file need not
%   exist: writeKS4Params creates it and ks4ForProbe loads it.
%
%   See also EphysPipelineConfig.writeKS4Params, EphysPipelineConfig.ks4ForProbe.

arguments
    probeFile (1,1) string
end

[folder, name] = fileparts(probeFile);
file = fullfile(folder, name + EphysPipelineConfig.KS4ParamsSuffix);
end
