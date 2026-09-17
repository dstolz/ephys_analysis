function writeJsonFile(file, s, opts)
%writeJsonFile  Write a struct as pretty-printed JSON, atomically.
%   writeJsonFile(file, s) encodes S with jsonencode (PrettyPrint when the
%   MATLAB release supports it), writes it to a temporary file next to FILE and
%   renames it into place, so a crash mid-write never leaves a truncated JSON
%   file behind.
%
%   Options
%     NonFinite  "null" (default) | "string"
%                jsonencode turns Inf/-Inf/NaN into null. With "string" they
%                are written as the strings "Inf", "-Inf" and "NaN" instead so
%                they survive a round trip; the reader (e.g. a config class
%                that knows each field's type) turns them back into numbers.
%     Pretty     logical (default true)
%
%   Errors with identifier writeJsonFile:CannotWrite when the file cannot be
%   written. See also readJsonFile, jsonencode.

arguments
    file (1,1) string
    s
    opts.NonFinite (1,1) string {mustBeMember(opts.NonFinite, ["null","string"])} = "null"
    opts.Pretty (1,1) logical = true
end

if opts.NonFinite == "string"
    s = stringifyNonFinite(s);
end

if opts.Pretty
    try
        txt = jsonencode(s, 'PrettyPrint', true);
    catch
        txt = jsonencode(s);   % releases before PrettyPrint support
    end
else
    txt = jsonencode(s);
end

file = char(file);
[outDir, base, ext] = fileparts(file);
if outDir == ""
    outDir = pwd;
end
if ~isfolder(outDir)
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('writeJsonFile:CannotWrite', 'Cannot create %s: %s', outDir, msg);
    end
end
tmp = fullfile(outDir, ['~' base ext '.partial']);

fid = fopen(tmp, 'w');
if fid < 0
    error('writeJsonFile:CannotWrite', 'Cannot open %s for writing.', tmp);
end
try
    fwrite(fid, txt, 'char');
    fclose(fid);
catch ME
    fclose(fid);
    if isfile(tmp); delete(tmp); end
    error('writeJsonFile:CannotWrite', 'Cannot write %s: %s', tmp, ME.message);
end

[ok, msg] = movefile(tmp, file, 'f');
if ~ok
    if isfile(tmp); delete(tmp); end
    error('writeJsonFile:CannotWrite', 'Cannot move %s to %s: %s', tmp, file, msg);
end
end


function v = stringifyNonFinite(v)
%stringifyNonFinite  Replace non-finite numerics with "Inf"/"-Inf"/"NaN" strings.
%   Recurses into structs (incl. struct arrays) and cells. A numeric array
%   containing at least one non-finite value becomes a cell array (so each
%   element can be a number or a string), which jsonencode writes as a JSON
%   array of mixed numbers and strings.
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
