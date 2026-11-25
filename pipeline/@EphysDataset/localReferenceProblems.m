function [p, notes] = localReferenceProblems(obj, opts)
%localReferenceProblems  Why the local reference cannot be used as it stands.
%   [P, NOTES] = ds.localReferenceProblems() checks LocalReferenceMap,
%   whether or not ArtifactConfig.LocalReference is on, and returns a
%   sentence per problem in P (a string row; none when the map can be
%   used):
%     - no group is assigned;
%     - a channel or reference past the recording's channel count;
%     - a reference channel that is excluded (Probe tab) or bad (while
%       Leave out bad channels is on): it would carry its fault onto its
%       whole group;
%     - the map was drawn on another probe than the dataset's own
%       (LocalReferenceProbe and ProbeFile name different files);
%     - a channel on the probe (its site connected) and not left out of
%       every step that is in no group: every shank must have a reference.
%       The channels are named with their shank (kcoords).
%   NOTES (a string row) says what could not be checked: without a
%   readable probe, whether every channel on it is in a group.
%
%   [P, NOTES] = ds.localReferenceProblems(ProbeFile=F) checks against
%   probe F (the one the pipeline resolves for a dataset without its own,
%   EphysPipeline.resolveProbe). By default: ProbeFile, else
%   LocalReferenceProbe.
%
%   [P, NOTES] = ds.localReferenceProblems(Map=M) checks the map M (a
%   draft, as LocalReferenceMap holds them) in place of the dataset's own,
%   as drawn on the probe checked against: LocalReferenceDialog shows
%   what a run would say of the map before it is saved.
%
%   prepareReference calls it while LocalReference is on, and a run stops
%   on the first problem (EphysDataset:LocalReference:Problems). The
%   Artifacts tab and LocalReferenceDialog show the problems.
%
%   See also EphysDataset.applyLocalReference, EphysDataset.prepareReference,
%   EphysDataset.channelLayout.

arguments
    obj (1,1) EphysDataset
    opts.ProbeFile (1,1) string = ""
    opts.Map = NaN   % NaN: the dataset's own LocalReferenceMap
end

p = strings(1, 0);
notes = strings(1, 0);
draft = ~isequaln(opts.Map, NaN);
if draft
    M = EphysDataset.normalizeLocalReferenceMap(opts.Map);
else
    M = obj.LocalReferenceMap;
end
if isempty(M)
    p(end + 1) = "No reference channel is assigned to any shank.";
    return
end
refs = [M.reference];
inGroups = [M.channels];

n = obj.NumChannels;
if ~isfinite(n); n = numel(obj.ChannelNumbers); end
if n > 0
    past = unique([refs(refs > n), inGroups(inGroups > n)]);
    if ~isempty(past)
        p(end + 1) = sprintf("Channel(s) %s are past the recording's %d channels.", ...
            EphysDataset.formatChannelList(past), n);
    end
end

% Left out by hand or as bad (not the zeros the map itself makes).
base = obj.ExcludeChannels;
if EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig).ExcludeBadChannels
    base = [base, obj.BadChannels];
end
base = unique(base);
badRef = refs(ismember(refs, base));
if ~isempty(badRef)
    p(end + 1) = sprintf(['Reference channel(s) %s are excluded or bad; a reference carries its ' ...
        'fault onto every channel of its group. Pick another.'], EphysDataset.formatChannelList(sort(badRef)));
end

pf = opts.ProbeFile;
if pf == ""; pf = obj.ProbeFile; end
if pf == ""; pf = obj.LocalReferenceProbe; end
if ~draft && obj.LocalReferenceProbe ~= "" && pf ~= "" && ~sameProbe(obj.LocalReferenceProbe, pf)
    p(end + 1) = sprintf("The map was drawn on probe %s, but %s is on probe %s. Assign the references again.", ...
        fileName(obj.LocalReferenceProbe), obj.Name, fileName(pf));
end

if pf == ""
    notes(end + 1) = "No probe: whether every shank has a reference is not checked.";
    return
end
L = obj.channelLayout(ProbeFile=pf);
if ~L.hasProbe
    notes(end + 1) = "The probe " + fileName(pf) + " cannot be read: whether every shank has a reference is not checked.";
    return
end
need = find(isfinite(L.x) & isfinite(L.y) & L.connected);
need = setdiff(need, [base, inGroups]);
if ~isempty(need)
    parts = strings(1, 0);
    for k = unique(L.shank(need))
        parts(end + 1) = sprintf("%s (shank %g)", ...
            EphysDataset.formatChannelList(need(L.shank(need) == k)), k); %#ok<AGROW>
    end
    p(end + 1) = "No reference for channel(s) " + strjoin(parts, ", ") + ...
        ": every shank on the probe needs one.";
end
end


function tf = sameProbe(a, b)
%sameProbe  Two probe files with one name (the folder may differ: outputs copied to another machine).
tf = strcmpi(fileName(a), fileName(b));
end


function s = fileName(f)
[~, nm, ext] = fileparts(f);
s = string(nm) + string(ext);
end
