function onTickDatasets(obj, mode)
%onTickDatasets  Tick shown only / Untick all: set the Data tab's Run ticks from what the table shows.
%   MODE "shown": Run ticked for the datasets the table shows and cleared
%   for those the Subject and Tags filters hide (no filter on: every
%   dataset ticked); "none": cleared for every dataset, shown or hidden.
%   As a tick in the table, the selection (and, in project mode, the
%   config) follows (onConfigChanged "ticks").
%
%   See also refreshDatasetsTable, onDatasetsTableEdited.
arguments
    obj (1,1) EphysAnalysisApp
    mode (1,1) string {mustBeMember(mode, ["shown" "none"])}
end
T = obj.DatasetsTable.Data;
if isempty(obj.Ticked) || ~istable(T) || ~ismember("Idx", string(T.Properties.VariableNames)); return; end
ticked = false(1, numel(obj.Ticked));
if mode == "shown"; ticked(T.Idx) = true; end
obj.Ticked = ticked;
obj.refreshDatasetsTable();
obj.onConfigChanged("ticks");
obj.setStatus(sprintf("%d of %d dataset(s) ticked to run.", nnz(obj.Ticked), numel(obj.Ticked)));
end
