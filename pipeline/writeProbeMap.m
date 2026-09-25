function writeProbeMap(file, probe)
%writeProbeMap  Write a Kilosort4 probe map .json.
%   writeProbeMap(FILE, PROBE) writes the probe struct PROBE (chanMap, xc,
%   yc, kcoords, n_chan and an optional notes; see probeMapProblems) to FILE
%   as pretty-printed JSON through writeJsonFile (atomic). The site arrays
%   are written as JSON lists whatever their length: jsonencode alone writes
%   a one-element array as a bare number, which Kilosort4 rejects (it wants
%   a list per site array), so a one-site probe, or a derived probe with one
%   channel left after EphysDataset.runKilosort's exclusions, would not load.
%   The fields are written in the order notes, chanMap, xc, yc, kcoords,
%   n_chan, then any others.
%
%   A probe Kilosort4 could not read is refused (writeProbeMap:BadProbe, the
%   message lists the problems) and FILE is left as it is.
%
%   Every probe map written from MATLAB goes through here: makeSyntheticProbe,
%   ProbeDesignerApp (Save) and EphysDataset.runKilosort (the derived
%   _excluded probe). probe_tool.py writes its own JSON from Python, where
%   json.dump writes lists whatever their length.
%
%   See also probeMapProblems, writeJsonFile, EphysDataset.runKilosort.

arguments
    file (1,1) string
    probe (1,1) struct
end

problems = probeMapProblems(probe);
if ~isempty(problems)
    error('writeProbeMap:BadProbe', 'Not a Kilosort4 probe map, so not written to %s:\n  %s', ...
        file, strjoin(problems, newline + "  "));
end

siteFields = ["chanMap" "xc" "yc" "kcoords"];
out = struct();
if isfield(probe, 'notes')
    out.notes = probe.notes;
end
for f = siteFields
    v = double(probe.(f));
    out.(f) = num2cell(v(:));      % a cell encodes as a JSON list, one site or many
end
out.n_chan = double(probe.n_chan);
rest = setdiff(string(fieldnames(probe)).', ["notes" siteFields "n_chan"], 'stable');
for f = rest
    out.(f) = probe.(f);
end
writeJsonFile(file, out);
end
