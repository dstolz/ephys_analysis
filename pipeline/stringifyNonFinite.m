function v = stringifyNonFinite(v)
%stringifyNonFinite  Replace non-finite numbers with "Inf" / "-Inf" / "NaN" strings.
%   V = stringifyNonFinite(V) recurses into structs (struct arrays too) and
%   cells. A numeric array holding at least one non-finite value becomes a
%   cell array (each element a number or a string), which jsonencode writes
%   as a JSON array of mixed numbers and strings. jsonencode would write
%   them as null, which does not survive a round trip; a reader that knows
%   each field's type (EphysPipelineConfig.normalizeSection) turns the
%   strings back into numbers.
%
%   writeJsonFile(..., NonFinite="string") applies it; so does the
%   provenance written into JSON outputs (ephysProvenance).
%
%   See also writeJsonFile, ephysProvenance.

if isstruct(v)
    fn = fieldnames(v);
    for i = 1:numel(v)
        for k = 1:numel(fn)
            v(i).(fn{k}) = stringifyNonFinite(v(i).(fn{k}));
        end
    end
elseif iscell(v)
    for i = 1:numel(v)
        v{i} = stringifyNonFinite(v{i});
    end
elseif isnumeric(v) && ~isempty(v) && any(~isfinite(v(:)))
    if isscalar(v)
        v = nonFiniteName(v);
    else
        c = num2cell(double(v));
        for i = 1:numel(c)
            if ~isfinite(c{i}); c{i} = nonFiniteName(c{i}); end
        end
        v = c;
    end
end
end


function s = nonFiniteName(x)
if isnan(x)
    s = "NaN";
elseif x > 0
    s = "Inf";
else
    s = "-Inf";
end
end
