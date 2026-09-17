function s = readJsonFile(file, opts)
%readJsonFile  Read and decode a JSON file.
%   S = readJsonFile(file) returns jsondecode(fileread(file)).
%
%   Options
%     ErrorOnFail  logical (default true). When false, any read or parse
%                  failure returns [] instead of raising.
%
%   Error identifiers: readJsonFile:NotFound, readJsonFile:BadJson.
%
%   Note that jsondecode collapses one-element arrays to scalars and lists
%   of one string to a char row; callers that know each field's expected
%   type (e.g. EphysPipelineConfig.normalizeSection) restore shapes.
%   Strings written by writeJsonFile(NonFinite="string") come back as the
%   strings "Inf"/"-Inf"/"NaN"; convert them where the field is numeric.
%
%   See also writeJsonFile, jsondecode.

arguments
    file (1,1) string
    opts.ErrorOnFail (1,1) logical = true
end

s = [];
if ~isfile(file)
    if opts.ErrorOnFail
        error('readJsonFile:NotFound', 'JSON file not found: %s', file);
    end
    return
end
try
    txt = fileread(file);
    s = jsondecode(txt);
catch ME
    if opts.ErrorOnFail
        error('readJsonFile:BadJson', 'Cannot parse %s: %s', file, ME.message);
    end
    s = [];
end
end
