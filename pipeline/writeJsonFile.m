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
%     Text       logical (default false). true: S is JSON text already
%                (a string or char row), written as it is, with the same
%                atomic rename. addToManifest changes one block of a
%                manifest this way, so the rest of the file is never
%                decoded and encoded again.
%
%   Errors with identifier writeJsonFile:CannotWrite when the file cannot be
%   written. See also readJsonFile, jsonencode.

arguments
    file (1,1) string
    s
    opts.NonFinite (1,1) string {mustBeMember(opts.NonFinite, ["null","string"])} = "null"
    opts.Pretty (1,1) logical = true
    opts.Text (1,1) logical = false
end

if opts.Text
    txt = char(s);
    if ~isrow(txt)
        error('writeJsonFile:CannotWrite', 'Text must be one string or char row of JSON.');
    end
else
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
[~, uid] = fileparts(tempname);   % a name of this write's own: two sessions writing one file never share it
tmp = fullfile(outDir, ['~' base ext '.' uid '.partial']);

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

