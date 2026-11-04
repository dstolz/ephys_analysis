function listFavorites(obj)
%listFavorites  FavoriteEntries made again from the stars in memory, and the Favorites drop-downs filled with them.
%   FavoriteEntries becomes every starred dataset, channel and unit of the
%   scanned datasets (Favorites), in dataset order, each dataset's star,
%   then its channels, then the units of the sort it uses: dataset (its
%   index), level, id and label. The label is the dataset's name, then
%   the item:
%     "subj1_day1"                                     the dataset
%     "subj1_day1 · channel 5 · 850 µm"                a channel
%     "subj1_day1 · unit 12 · su · ch 5 · 850 µm"      a sorted unit
%   A unit's class, channel and depth come from the units read when its
%   dataset was opened (DatasetUnits, refreshDatasetLabels), a channel's
%   depth from the probe map of its loaded source (Runner.Sources); a
%   dataset not opened yet keeps the short label ("subj1_day1 · unit 12",
%   "subj1_day1 · channel 5"): nothing is read to label the list. The
%   Favorites drop-downs of the Alignment and Figures tabs list them,
%   narrowed by their filters (fillFavorites). selectDataset calls it once
%   the dataset is opened, so its entries fill in.
%
%   See also refreshFavorites, fillFavorites, refreshDatasetLabels.
r = obj.Runner;
dataset = zeros(0, 1);
level = strings(0, 1);
id = zeros(0, 1);
label = strings(0, 1);
if ~isempty(r) && numel(obj.Favorites) == numel(r.Keys)
    units = obj.DatasetUnits;
    for k = 1:numel(r.Keys)
        L = obj.Favorites(k).list();
        n = height(L);
        if n == 0; continue; end
        lab = r.Names(k) + " · " + L.label;
        lab(L.level == "dataset") = r.Names(k);
        U = [];
        if isa(units, 'containers.Map')
            key = datasetSortKey(r, k);
            if isKey(units, key); U = units(key); end
        end
        probe = [];
        if isKey(r.Sources, char(r.Keys(k)))
            src = r.Sources(char(r.Keys(k)));
            if isfield(src, 'probe'); probe = src.probe; end
        end
        for i = 1:n
            switch L.level(i)
                case "unit"
                    lab(i) = lab(i) + unitText(U, L.id(i));
                case "channel"
                    lab(i) = lab(i) + depthText(channelDepth(probe, L.id(i)));
            end
        end
        dataset = [dataset; repmat(k, n, 1)]; %#ok<AGROW>
        level = [level; L.level]; %#ok<AGROW>
        id = [id; L.id]; %#ok<AGROW>
        label = [label; lab]; %#ok<AGROW>
    end
end
obj.FavoriteEntries = table(dataset, level, id, label);
fillFavorites(obj, obj.AlignFavorites);
fillFavorites(obj, obj.FigureFavorites);
end


function s = unitText(U, id)
%unitText  " · su · ch 5 · 850 µm": the unit's class, channel and depth from U (DatasetUnits' table), "" when not known.
s = "";
if ~istable(U) || height(U) == 0; return; end
j = find(U.unitId == id, 1);
if isempty(j); return; end
if U.class(j) ~= ""; s = s + " · " + U.class(j); end
if isfinite(U.channel(j)); s = s + " · ch " + U.channel(j); end
s = s + depthText(U.depth(j));
end


function y = channelDepth(probe, ch)
%channelDepth  Recording channel CH's site y (µm) in the probe map (chanMap 0-based, yc); NaN when not known.
y = NaN;
if isempty(probe) || ~isstruct(probe) || ~all(isfield(probe, {'chanMap', 'yc'})); return; end
s = find(double(probe.chanMap(:)) + 1 == ch, 1);
if ~isempty(s) && s <= numel(probe.yc); y = double(probe.yc(s)); end
end


function s = depthText(y)
s = "";
if isfinite(y); s = " · " + compose("%g µm", round(y)); end
end
