function file = writeKS4Params(probeFile, values, opts)
%writeKS4Params  Save Kilosort4 parameters as a probe's parameter file.
%   FILE = EphysPipelineConfig.writeKS4Params(PROBEFILE, VALUES) writes the
%   Kilosort4 parameters in struct VALUES (kilosortParamSpec names with typed
%   values, e.g. part of cfg.Sorting.KS4 or ks4ProbeDefaults' result) to the
%   probe map's parameter file, FILE = ks4ParamsFile(PROBEFILE), which
%   ks4ForProbe loads. As in a config file, a blank (auto) value is written as
%   [] and Inf as "Inf". Parameters are written in kilosortParamSpec order.
%
%   Options
%     Description  free text: where the values come from
%     Reasons      struct of text per parameter, e.g. ks4ProbeDefaults'
%                  report.Reasons (written only for parameters in VALUES)
%     Overwrite    replace an existing file (default false)
%
%   File (schema EphysPipelineConfig.KS4ParamsSchema)
%     { "schema": "ephys-ks4-params/1", "probe": <probe map file name>,
%       "description": <text>, "KS4": { <parameter>: <value>, ... },
%       "reasons": { <parameter>: <text>, ... } }   (reasons only when given)
%
%   Errors: EphysPipelineConfig:BadParams (no parameters, or names that are
%   not Kilosort4 parameters), EphysPipelineConfig:ParamsExist (the file
%   exists and Overwrite is false), EphysPipelineConfig:BadValue,
%   writeJsonFile:CannotWrite.
%
%   See also EphysPipelineConfig.ks4ForProbe, EphysPipelineConfig.ks4ProbeDefaults.

arguments
    probeFile (1,1) string
    values (1,1) struct
    opts.Description (1,1) string = ""
    opts.Reasons (1,1) struct = struct()
    opts.Overwrite (1,1) logical = false
end

spec = EphysPipelineConfig.kilosortParamSpec();
known = string({spec.name});
names = string(fieldnames(values)).';
if isempty(names)
    error('EphysPipelineConfig:BadParams', 'No Kilosort4 parameters to write.');
end
bad = setdiff(names, known, 'stable');
if ~isempty(bad)
    error('EphysPipelineConfig:BadParams', 'Not Kilosort4 parameters: %s.', strjoin(bad, ", "));
end
file = EphysPipelineConfig.ks4ParamsFile(probeFile);
if isfile(file) && ~opts.Overwrite
    error('EphysPipelineConfig:ParamsExist', '%s already exists.', file);
end

typed = EphysPipelineConfig.normalizeSection("Sorting", struct('KS4', values)).KS4;
ks4 = struct();
reasons = struct();
for name = known(ismember(known, names))
    ks4.(name) = typed.(name);
    if isfield(opts.Reasons, name)
        reasons.(name) = string(opts.Reasons.(name));
    end
end

[~, pn, pe] = fileparts(probeFile);
s = struct();
s.schema = EphysPipelineConfig.KS4ParamsSchema;
s.probe = pn + pe;
s.description = opts.Description;
s.KS4 = ks4;
if ~isempty(fieldnames(reasons))
    s.reasons = reasons;
end
writeJsonFile(file, s, NonFinite="string");
end
