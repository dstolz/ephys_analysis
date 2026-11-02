function v = stringifyNonFinite(v)
%stringifyNonFinite  Replace non-finite numbers with "Inf" / "-Inf" / "NaN" strings.
%   V = stringifyNonFinite(V) recurses into structs (struct arrays too) and
%   cells. A numeric vector holding at least one non-finite value becomes a
%   cell array (each element a number or a string), which jsonencode writes
%   as a JSON array of mixed numbers and strings; a matrix becomes a cell
%   column of its rows, each a numeric row or a cell row, so it is written
%   as a list of lists ([[1,"NaN"],[3,4]]) as the matrix itself is.
%   jsonencode would write them as null, which does not survive a round trip; a reader that knows
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
    elseif ismatrix(v) && size(v, 1) > 1 && size(v, 2) > 1
        % jsonencode writes a cell array as one flat list, column by column,
        % so a matrix goes row by row: a list of its rows, as jsonencode
        % writes the matrix itself ([[1,2],[3,4]]). A row without a
        % non-finite number stays a numeric row.
        rows = num2cell(double(v), 2);
        for i = 1:numel(rows)
            rows{i} = stringifyNonFinite(rows{i});
        end
        v = rows;
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
