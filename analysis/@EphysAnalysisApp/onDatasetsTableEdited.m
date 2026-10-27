function onDatasetsTableEdited(obj, ~)
%onDatasetsTableEdited  A Run tick changed: the datasets a run (and, in project mode, the config) uses; or a star (★).
%   A ★ ticked or cleared stars or unstars its dataset, written at once
%   beside its outputs (starItem); the Run ticks are left alone then. The
%   datasets the filter hides (not in the table) keep their ticks.
T = obj.DatasetsTable.Data;
if ~istable(T) || ~ismember("Run", string(T.Properties.VariableNames)); return; end
if ismember("Star", string(T.Properties.VariableNames)) && numel(obj.Favorites) == numel(obj.Ticked)
    was = reshape([obj.Favorites(T.Idx).Dataset], [], 1);
    rows = find(logical(T.Star) ~= was);
    if ~isempty(rows)
        for r = reshape(rows, 1, [])
            starItem(obj, T.Idx(r), "dataset", [], logical(T.Star(r)));
        end
        return
    end
end
ticked = obj.Ticked;
ticked(T.Idx) = logical(T.Run);   % a row's Idx is its dataset, whatever order the rows are in
obj.Ticked = ticked;
obj.onConfigChanged("ticks");
obj.setStatus(sprintf("%d of %d dataset(s) ticked to run.", nnz(obj.Ticked), numel(obj.Ticked)));
end
