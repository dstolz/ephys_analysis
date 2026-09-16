function onPipelineProgress(obj, evt)
%onPipelineProgress  Update the Run-tab bars from an EphysPipeline event.
if ~isvalid(obj.Fig); return; end
frac = 0;
if evt.total > 0; frac = min(max(evt.done / evt.total, 0), 1); end
obj.setRunBar(obj.RunStepBar, frac);
obj.RunStepText.Text = sprintf('%d%%', round(100 * frac));
if evt.count > 0
    overall = (evt.index - 1 + frac) / evt.count;
    obj.setRunBar(obj.RunOverallBar, overall);
    obj.RunOverallText.Text = sprintf('%s %d/%d', evt.step, evt.index, evt.count);
end
obj.RunStepLabel.Text = char(evt.step + ": " + evt.dataset + " - " + evt.message);
drawnow limitrate;
end
