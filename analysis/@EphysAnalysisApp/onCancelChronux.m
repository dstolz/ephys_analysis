function onCancelChronux(obj)
%onCancelChronux  Ask the Chronux tab's running analysis to stop (chronuxCheck throws at its next check).
obj.ChronuxCancelRequested = true;
obj.ChronuxCancelButton.Enable = "off";
obj.ChronuxStatusLabel.Text = "Canceling ...";
end
