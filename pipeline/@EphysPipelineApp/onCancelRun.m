function onCancelRun(obj)
%onCancelRun  Ask the running pipeline to stop at its next progress report (after the current dataset).
%   The pipeline looks for the request each time it reports progress, once
%   per dataset of the step under way; a dataset that is being processed
%   is finished first.
if ~obj.RunActive || isempty(obj.Pipe); return; end
obj.Pipe.cancel();
obj.RunCancelButton.Enable = "off";
obj.ToolbarCancelTool.Enable = "off";
obj.RunStepLabel.Text = "Canceling after the current dataset...";
end
