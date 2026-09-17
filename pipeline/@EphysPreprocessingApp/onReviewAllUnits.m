function onReviewAllUnits(obj)
    % Clear the unit selection and show all units again.
    if isempty(obj.ReviewData); return; end
    obj.ReviewSelectedUnit = 0;
    if ~isempty(obj.ReviewUnitsTable.Selection)
        obj.ReviewUnitsTable.Selection = [];
    end
    obj.renderReviewPlots();
end
