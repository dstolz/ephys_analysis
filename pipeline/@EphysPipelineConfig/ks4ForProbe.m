function [sorting, report] = ks4ForProbe(sorting, probeFile)
%ks4ForProbe  Load a probe's Kilosort4 parameter file into a Sorting section.
%   [S, REPORT] = EphysPipelineConfig.ks4ForProbe(cfg.Sorting, PROBEFILE) reads
%   the parameter file of the probe map PROBEFILE (ks4ParamsFile:
%   <name>.ks4.json next to it) and sets every Kilosort4 parameter the file
%   lists. The other parameters and KS4ExtraJSON are kept. Values are read as
%   in a config file: [] or null is blank (Kilosort's own default) and "Inf"
%   is Inf. writeKS4Params writes such a file; ks4ProbeDefaults derives good
%   values from the probe layout.
%
%   REPORT struct
%     File         the parameter file
%     Description  its description ("" when it has none)
%     Changes      table Parameter, Old, New, Changed, Reason: one row per
%                  parameter in the file, in kilosortParamSpec order, values as
%                  edit-field text, Reason from the file's "reasons" ("" when
%                  it gives none)
%     Notes        string column: KS4ExtraJSON entries that override a loaded
%                  value
%
%   Errors: EphysPipelineConfig:NoProbeParams (no parameter file),
%   EphysPipelineConfig:BadParams (another schema, no KS4 parameters, or names
%   that are not Kilosort4 parameters), readJsonFile:BadJson,
%   EphysPipelineConfig:BadValue (a value of the wrong type).
%
%   See also EphysPipelineConfig.writeKS4Params, EphysPipelineConfig.ks4ProbeDefaults,
%   EphysPipelineConfig.kilosortParamSpec.

arguments
    sorting (1,1) struct
    probeFile (1,1) string
end

sorting = EphysPipelineConfig.normalizeSection("Sorting", sorting);
file = EphysPipelineConfig.ks4ParamsFile(probeFile);
if ~isfile(file)
    error('EphysPipelineConfig:NoProbeParams', 'No Kilosort4 parameter file for %s (expected %s).', ...
        probeFile, file);
end
s = readJsonFile(file);
if ~isstruct(s) || ~isscalar(s) || ~isfield(s, 'schema') ...
        || string(s.schema) ~= EphysPipelineConfig.KS4ParamsSchema
    error('EphysPipelineConfig:BadParams', '%s is not an %s file.', file, EphysPipelineConfig.KS4ParamsSchema);
end
if ~isfield(s, 'KS4') || ~isstruct(s.KS4) || ~isscalar(s.KS4) || isempty(fieldnames(s.KS4))
    error('EphysPipelineConfig:BadParams', '%s lists no Kilosort4 parameters (KS4).', file);
end
spec = EphysPipelineConfig.kilosortParamSpec();
known = string({spec.name});
names = string(fieldnames(s.KS4)).';
bad = setdiff(names, known, 'stable');
if ~isempty(bad)
    error('EphysPipelineConfig:BadParams', '%s: not Kilosort4 parameters: %s.', file, strjoin(bad, ", "));
end
typed = EphysPipelineConfig.normalizeSection("Sorting", struct('KS4', s.KS4)).KS4;
reasons = struct();
if isfield(s, 'reasons') && isstruct(s.reasons) && isscalar(s.reasons)
    reasons = s.reasons;
end

order = known(ismember(known, names));
k = numel(order);
Parameter = strings(k, 1); Old = strings(k, 1); New = strings(k, 1);
Changed = false(k, 1); Reason = strings(k, 1);
for i = 1:k
    name = order(i);
    kind = spec(known == name).kind;
    old = sorting.KS4.(name);
    Parameter(i) = name;
    Old(i) = EphysPipelineConfig.ks4ParamText(kind, old);
    New(i) = EphysPipelineConfig.ks4ParamText(kind, typed.(name));
    Changed(i) = ~sameValue(old, typed.(name));
    if isfield(reasons, name)
        Reason(i) = string(reasons.(name));
    end
    sorting.KS4.(name) = typed.(name);
end
sorting = EphysPipelineConfig.normalizeSection("Sorting", sorting);

notes = strings(0, 1);
extra = [];
if strtrim(sorting.KS4ExtraJSON) ~= ""
    try
        extra = jsondecode(char(sorting.KS4ExtraJSON));
    catch
        % an unparseable block is reported by validate / ks4Settings
    end
end
if isstruct(extra) && isscalar(extra)
    over = intersect(Parameter.', string(fieldnames(extra)).', 'stable');
    if ~isempty(over)
        notes(end+1, 1) = "The extra settings JSON (KS4ExtraJSON) sets " + strjoin(over, ", ") + ...
            ", which overrides the loaded value.";
    end
end

description = "";
if isfield(s, 'description') && (ischar(s.description) || isstring(s.description))
    description = string(s.description);
end

report = struct();
report.File = file;
report.Description = description;
report.Changes = table(Parameter, Old, New, Changed, Reason);
report.Notes = notes;
end


function tf = sameValue(a, b)
if isempty(a) || isempty(b)
    tf = isempty(a) && isempty(b);
else
    tf = isequal(double(a), double(b));
end
end
