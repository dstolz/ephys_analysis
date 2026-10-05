function onReviewUnitSelected(obj, evt)
    % Table row click -> focus the plots on that single unit.
    % Look up by cluster ID so column-sort doesn't break the mapping.
    if isempty(obj.ReviewData) || isempty(evt.Indices)
        return
    end
    row = evt.Indices(1);
    T = obj.ReviewUnitsTable.Data;
    if iscell(T) && size(T, 1) >= row
        cid = T{row, 1};
    else
        return
    end
    unitIdx = find(obj.ReviewData.clusterID == cid, 1);
    if isempty(unitIdx); return; end
    obj.ReviewSelectedUnit = unitIdx;
    obj.renderReviewPlots();
end
