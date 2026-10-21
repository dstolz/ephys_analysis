function [s, out] = sortIdentity(out, folder, name)
%sortIdentity  The sort a dataset uses now: its phy folder (relative to its output folder when inside it) and spike_times.npy's size.
%   [S, OUT] = sortIdentity(OUT, FOLDER, NAME). OUT is the dataset's
%   DatasetOutputs, or [] to search its output folder FOLDER for one
%   (DatasetOutputs(FOLDER, Name=NAME)), returned for the next call. S is
%   struct(sort, spikeTimesBytes): sort "" without a sort, spikeTimesBytes
%   NaN without spike times. A unit's star (DatasetFavorites) and its note
%   (DatasetNotes) both record it, so a new sort -- in another folder, or
%   over the old one with other spike times -- shows neither.
%
%   See also DatasetFavorites, DatasetNotes, EphysDataset.resolvePhyDir.
s = struct('sort', "", 'spikeTimesBytes', NaN);
d = "";
try
    if isempty(out); out = DatasetOutputs(folder, Name=name); end
    d = string(out.SortingDir);
catch
end
if ~isempty(d) && isscalar(d) && d ~= ""
    phy = string(EphysDataset.resolvePhyDir(d));
    if isfolder(phy)
        s.sort = relativeTo(phy, folder);
        b = dir(fullfile(phy, 'spike_times.npy'));
        if isscalar(b); s.spikeTimesBytes = b.bytes; end
    end
end
end


function r = relativeTo(p, base)
%relativeTo  P below BASE as "a/b" ("." for BASE itself), else P in full with "/".
p = strrep(string(p), '\', '/');
base = strrep(string(base), '\', '/');
base = regexprep(base, '/+$', '');
if strcmpi(p, base)
    r = ".";
elseif base ~= "" && startsWith(lower(p), lower(base) + "/")
    r = extractAfter(p, strlength(base) + 1);
else
    r = p;
end
r = regexprep(r, '/+$', '');
end
