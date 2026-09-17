function [ks4, errMsg] = ks4Settings(sorting)
%ks4Settings  Kilosort4 settings struct from the Sorting section.
%   [KS4, ERRMSG] = EphysPipelineConfig.ks4Settings(cfg.Sorting) returns the
%   scalar struct passed to EphysDataset.runSpikeInterface as ExtraSettings.
%   Typed values come from Sorting.KS4 (per kilosortParamSpec); "auto"
%   values - nullable parameters left [] and floatinf parameters at Inf -
%   are OMITTED so Kilosort4 falls back to its own default. The free-form
%   Sorting.KS4ExtraJSON block is merged last and overrides named fields.
%   ERRMSG is "" on success or describes the JSON parse failure (KS4 is then
%   the named fields only).
%
%   See also EphysPipelineConfig.kilosortParamSpec, EphysDataset.runSpikeInterface.

arguments
    sorting (1,1) struct
end

sorting = EphysPipelineConfig.normalizeSection("Sorting", sorting);
spec = EphysPipelineConfig.kilosortParamSpec();
ks4 = struct();
errMsg = "";

for i = 1:numel(spec)
    p = spec(i);
    if ~isfield(sorting.KS4, p.name); continue; end
    v = sorting.KS4.(p.name);
    switch p.kind
        case 'bool'
            ks4.(p.name) = logical(v);
        case 'int'
            ks4.(p.name) = round(double(v));
        case 'float'
            ks4.(p.name) = double(v);
        case 'floatinf'
            if isempty(v) || ~isfinite(v); continue; end
            ks4.(p.name) = double(v);
        case 'nullable'
            if isempty(v) || any(isnan(v)); continue; end
            ks4.(p.name) = double(v(1));
        case 'vector'
            if isempty(v); continue; end
            ks4.(p.name) = double(v(:).');
    end
end

raw = strtrim(string(sorting.KS4ExtraJSON));
if raw ~= "" && raw ~= "{}"
    try
        extra = jsondecode(char(raw));
    catch ME
        errMsg = "KS4 extra settings JSON: " + string(ME.message);
        return
    end
    if isstruct(extra)
        for f = string(fieldnames(extra)).'
            ks4.(f) = extra.(f);
        end
    elseif ~isempty(extra)
        errMsg = "KS4 extra settings JSON must be an object ({...}).";
    end
end
end
