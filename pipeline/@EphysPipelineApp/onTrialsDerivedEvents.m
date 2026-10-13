function onTrialsDerivedEvents(obj)
%onTrialsDerivedEvents  Open the Derived events window (or bring it to the front).
%   The window (DerivedEventsDialog) edits Behavior.DerivedEvents: each edit
%   goes into the config at once (TrialsDerivedEvents, onConfigChanged),
%   and the Trials plot and the line beside the button follow. It counts
%   each event on the loaded dataset's pairing.
%
%   See also DerivedEventsDialog, syncTrialsDerived, deriveEvents.

dlg = obj.TrialsDerivedDialog;
if ~isempty(dlg) && isvalid(dlg) && isvalid(dlg.Fig)
    figure(dlg.Fig);
    return
end
obj.TrialsDerivedDialog = DerivedEventsDialog(obj.TrialsDerivedEvents, Parent=obj.Fig, ...
    OnChange=@(defs) derivedChanged(obj, defs));
obj.syncTrialsDerived(true);
end


function derivedChanged(obj, defs)
%derivedChanged  An edit in the window: into the config, the plot and the label.
obj.TrialsDerivedEvents = defs;
obj.onConfigChanged();
obj.refreshTrialsPlot();
obj.syncTrialsDerived();
end
