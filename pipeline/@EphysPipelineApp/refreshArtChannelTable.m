function refreshArtChannelTable(obj)
%refreshArtChannelTable  The last preview's per-channel counts, in the
%   Artifacts tab's table. With a probe assigned to the active dataset the
%   table gains a Shank column, and its rows follow the probe layout while
%   "Order channels by probe layout" is ticked (recording order otherwise).
%   Reads ArtView.summary (onDetectArtifacts) and ArtView.layout
%   (syncArtProbeControls); empty until a preview has run.
%
%   See also onDetectArtifacts, syncArtProbeControls, EphysDataset.channelLayout.

t = obj.ArtChannelTable;
if isempty(t) || ~isvalid(t); return; end
L = obj.ArtView.layout;
s = obj.ArtView.summary;
hasProbe = ~isempty(L) && L.hasProbe && (isempty(s) || numel(L.order) == s.nChan);

if hasProbe
    t.ColumnName  = {'Ch', 'Name', 'Shank', '#Samples', '% of duration'};
    t.ColumnWidth = {34, '1x', 52, 74, 100};
else
    t.ColumnName  = {'Ch', 'Name', '#Samples', '% of duration'};
    t.ColumnWidth = {34, '1x', 74, 100};
end
nCol = numel(t.ColumnName);
if isempty(s) || s.nChan == 0
    t.Data = cell(0, nCol);
    return
end

nCh = s.nChan;
names = s.channelNames;
if numel(names) ~= nCh
    names = "ch" + string(1:nCh);
end
ord = 1:nCh;
if hasProbe && logical(obj.ArtProbeOrderCheckBox.Value)
    ord = L.order;
end

C = cell(nCh, nCol);
for r = 1:nCh
    k = ord(r);
    C{r, 1} = k;
    C{r, 2} = char(names(k));
    if hasProbe
        if isnan(L.shank(k)); C{r, 3} = ''; else; C{r, 3} = L.shank(k); end
    end
    C{r, nCol - 1} = s.channelCounts(k);
    C{r, nCol}     = sprintf('%.3f', s.channelPct(k));
end
t.Data = C;
end
