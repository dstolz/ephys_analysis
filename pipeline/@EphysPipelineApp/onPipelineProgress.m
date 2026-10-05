function onPipelineProgress(obj, evt)
%onPipelineProgress  Update the Run-tab bars, results and diagram from an EphysPipeline event.
%   An event with dataset "" (index 0) marks the start of a step. The
%   results table (the Run's rows since runPipeline cleared it) takes the
%   running pipeline's Results (obj.Pipe) when the two have not as many
%   rows (the pipeline added one since), so each row shows at the next
%   event and the table is not rebuilt at every event; a row the Kilosort4
%   monitor restates reaches it through markKSResult.
if ~isvalid(obj.Fig); return; end
if ~isempty(obj.Pipe) && isvalid(obj.Pipe) && height(obj.Pipe.Results) ~= height(obj.RunResultsTable.Data)
    obj.RunResultsTable.Data = obj.Pipe.Results;
end
frac = 0;
if evt.total > 0; frac = min(max(evt.done / evt.total, 0), 1); end
obj.setRunBar(obj.RunStepBar, frac);
obj.RunStepText.Text = sprintf('%d%%', round(100 * frac));
if evt.count > 0
    overall = (max(evt.index, 1) - 1 + frac) / evt.count;
    obj.setRunBar(obj.RunOverallBar, overall);
    obj.RunOverallText.Text = sprintf('%s %d/%d', evt.step, evt.index, evt.count);
end
if evt.dataset == ""
    obj.RunStepLabel.Text = char(evt.step + ": " + evt.message);
else
    obj.RunStepLabel.Text = char(evt.step + ": " + evt.dataset + " - " + evt.message);
end
obj.updateRunDiagram(evt);
drawnow limitrate;
end
