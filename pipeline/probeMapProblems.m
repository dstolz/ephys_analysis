function problems = probeMapProblems(probe)
%probeMapProblems  Why Kilosort4 could not read a probe map, when it could not.
%   PROBLEMS = probeMapProblems(PROBE) checks PROBE, a Kilosort4 probe .json
%   file or its decoded struct, against what kilosort.io.load_probe and
%   run_kilosort (Kilosort 4.1.7) read from a JSON probe, and returns one
%   line per problem as a string column, empty when Kilosort4 reads the
%   probe. Every problem here fails inside Kilosort4, some only after the
%   .bin has been written, so EphysDataset.runKilosort refuses such a probe
%   before writing anything (EphysDataset:runKilosort:BadProbe), writeProbeMap
%   refuses to write one, and the Probe tab and DatasetTracker.probeMeta flag
%   it.
%
%   A probe map is a JSON object with
%     chanMap   the 0-based .bin row of every site (integers)
%     xc, yc    the site positions in um
%     kcoords   the shank of every site (all 0 on a single shank). Kilosort4
%               places templates per shank and has no default for the field.
%     n_chan    the total channel count, a positive integer
%     notes     optional text
%   chanMap, xc, yc and kcoords are finite numeric vectors of one and the
%   same length, at least one site. Any other field must not be a list:
%   Kilosort4 reads every JSON array in the file as one value per site, so a
%   list of site names, say, stops the probe loading. Text, a number and a
%   nested object are left alone.
%
%   A one-site map decodes to scalars in MATLAB, which this check cannot tell
%   from bare numbers in the file; writeProbeMap writes every site array as a
%   JSON list, which is what Kilosort4 needs.
%
%   See also writeProbeMap, EphysDataset.runKilosort, DatasetTracker.probeMeta.

arguments
    probe
end

problems = strings(0, 1);

if (ischar(probe) || isstring(probe)) && isscalar(string(probe))
    file = string(probe);
    if ~isfile(file)
        problems(end+1, 1) = "file not found: " + file;
        return
    end
    try
        probe = jsondecode(fileread(file));
    catch ME
        problems(end+1, 1) = "not valid JSON: " + string(ME.message);
        return
    end
end
if ~isstruct(probe) || ~isscalar(probe)
    problems(end+1, 1) = "not a JSON object";
    return
end

siteFields = ["chanMap" "xc" "yc" "kcoords"];
what = struct( ...
    'chanMap', "the 0-based .bin row of every site", ...
    'xc',      "the x position of every site in um", ...
    'yc',      "the y position of every site in um", ...
    'kcoords', "the shank of every site (all 0 on a single shank); Kilosort4 has no default", ...
    'n_chan',  "the total channel count");
for f = [siteFields "n_chan"]
    if ~isfield(probe, f)
        problems(end+1, 1) = "no " + f + ": " + what.(f); %#ok<AGROW>
    end
end

% The site arrays: finite numeric vectors of one length.
n = NaN(1, numel(siteFields));
for k = 1:numel(siteFields)
    f = siteFields(k);
    if ~isfield(probe, f); continue; end
    v = probe.(f);
    if ~(isnumeric(v) || islogical(v))
        problems(end+1, 1) = f + " is not numeric"; %#ok<AGROW>
    elseif isempty(v)
        problems(end+1, 1) = f + " is empty"; %#ok<AGROW>
    elseif ~isvector(v)
        problems(end+1, 1) = f + " is not a flat list"; %#ok<AGROW>
    elseif ~all(isfinite(v(:)))
        problems(end+1, 1) = f + " has a value that is not a finite number"; %#ok<AGROW>
    else
        n(k) = numel(v);
    end
end
if ~isnan(n(1))
    v = double(probe.chanMap(:));
    if any(v ~= round(v)) || any(v < 0)
        problems(end+1, 1) = "chanMap must hold 0-based integer .bin rows";
    end
end
ok = ~isnan(n);
if nnz(ok) > 1 && numel(unique(n(ok))) > 1
    problems(end+1, 1) = "the site arrays differ in length: " + ...
        strjoin(siteFields(ok) + " " + n(ok), ", ");
end

if isfield(probe, 'n_chan')
    v = probe.n_chan;
    if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v == round(v) && v >= 1)
        problems(end+1, 1) = "n_chan is not a positive integer";
    end
end

% Every other field: anything but a list.
names = string(fieldnames(probe)).';
for f = names(~ismember(names, [siteFields "n_chan"]))
    if isList(probe.(f))
        problems(end+1, 1) = "'" + f + "' is a list: Kilosort4 reads every JSON array as one value per site"; %#ok<AGROW>
    end
end
end


function tf = isList(v)
%isList  True for what a JSON array decodes to (or a MATLAB array would encode as).
%   A JSON array of numbers or of true/false decodes to a numeric or logical
%   array, of strings to a cell, of objects to a struct array, and a nested
%   array to a matrix; text (char row or one string) never comes from a list.
tf = iscell(v) ...
    || (isstruct(v) && ~isscalar(v)) ...
    || ((isnumeric(v) || islogical(v)) && ~isscalar(v)) ...
    || (isstring(v) && ~isscalar(v));
end
