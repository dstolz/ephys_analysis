function onCancelConvert(obj)
    % Ask a running conversion to stop at the next step boundary.
    if ~obj.ConvRunning; return; end
    obj.ConvCancelRequested = true;
    obj.ConvCancelButton.Enable = "off";
    obj.ConvStepLabel.Text = "Cancelling after the current step...";
end
