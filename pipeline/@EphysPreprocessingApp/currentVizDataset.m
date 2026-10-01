function d = currentVizDataset(obj)
    % Dataset handle backing the currently cached Visualize data ([] none).
    % It is the dataset the plot was made from (VizDataset), even when a
    % rescan dropped it; syncVizDataset then flags the plot as out of date.
    d = EphysDataset.empty;
    if ~isempty(obj.VizDataset) && isvalid(obj.VizDataset)
        d = obj.VizDataset;
    end
end
