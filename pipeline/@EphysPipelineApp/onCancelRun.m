function onCancelRun(obj)
%onCancelRun  Ask the running pipeline to stop at the next boundary.
if ~obj.RunActive || isempty(obj.Pipe); return; end
obj.Pipe.cancel();
obj.RunCancelButton.Enable = "off";
obj.ToolbarCancelTool.Enable = "off";
obj.RunStepLabel.Text = "Canceling after the current step...";
end
