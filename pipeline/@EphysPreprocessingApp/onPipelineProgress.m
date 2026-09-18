function onPipelineProgress(obj, evt)
%onPipelineProgress  Update the Run-tab bars and the run diagram from an EphysPipeline event.
%   An event with dataset "" (index 0) marks the start of a step.
if ~isvalid(obj.Fig); return; end
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
