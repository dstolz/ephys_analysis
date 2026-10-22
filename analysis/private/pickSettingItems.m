function pick = pickSettingItems(I, keys, id)
%pickSettingItems  The rows of I (figureSettingItems) that KEYS name.
%   PICK = pickSettingItems(I, KEYS, ID) is a logical per row of I: a key
%   names its row, the start of keys before a dot every row under it (a
%   part: "style"; a panel: "panel.psth_1"); KEYS missing names every row.
%   A key that names no row raises ID, unless it is a part's
%   (figureSettingParts) with no setting in this figure (no remembered
%   look, no panel).
%
%   See also copyFigureSettings, figureLookToDesign.
if isscalar(keys) && ismissing(keys)
    pick = true(height(I), 1);
    return
end
parts = figureSettingParts().Part;
pick = false(height(I), 1);
for key = reshape(keys, 1, [])
    hit = I.Key == key | startsWith(I.Key, key + ".");
    if ~any(hit) && ~ismember(key, parts)
        error(id, 'The figure has no setting "%s" (figureSettingItems'' keys, or a part: %s).', key, strjoin(parts, ", "));
    end
    pick = pick | hit;
end
end
