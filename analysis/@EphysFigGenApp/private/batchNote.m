function t = batchNote(spec)
%batchNote  The status line's word on panels whose y range a run shares (yLimMode "batch"): the preview draws its own.
t = "";
ids = figureBatchPanels(spec);
if isempty(ids); return; end
t = "; Y limits of " + strjoin(ids, ", ") + " are shared by every observation when generated (here this one's own range)";
end
