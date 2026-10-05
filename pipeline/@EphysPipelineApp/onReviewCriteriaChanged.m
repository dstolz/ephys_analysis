function onReviewCriteriaChanged(obj)
%onReviewCriteriaChanged  A good-unit criterion was edited: the config, then the QC column.
%   The criteria are the config's Sorting.Quality (gatherSortingSection), so
%   the edit marks the config changed; the loaded units are judged again
%   (unitQualityPass) without computing their metrics again. A threshold
%   that does not parse is refused by gatherConfig, as any other field.
obj.onConfigChanged();
if isempty(obj.ReviewData) || ~isfield(obj.ReviewData, 'units')
    return
end
[S, err] = obj.gatherSortingSection();
if err ~= ""
    obj.setStatus(err, "");
    return
end
obj.ReviewData.qc = judgeUnits(obj.ReviewData.units, S.Quality);
obj.showReviewUnits();
end
