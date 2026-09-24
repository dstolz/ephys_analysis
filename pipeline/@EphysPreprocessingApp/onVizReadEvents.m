function onVizReadEvents(obj)
%onVizReadEvents  Read events: the plotted dataset's digital inputs from the recording.
%   For a dataset with no Signals extract and no events file yet. Reading
%   the events can mean reading the whole recording; the result is kept in
%   <Name>_events.mat, so the next load finds it (loadVizEvents).
%
%   See also loadVizEvents, EphysDataset.digitalEvents.

d = obj.currentVizDataset();
if isempty(d) || isempty(obj.VizData); return; end
dlg = uiprogressdlg(obj.Fig, "Title", "Visualize", "Indeterminate", "on", ...
    "Message", "Reading the digital inputs of " + d.Name + "...");
closer = onCleanup(@() delete(dlg));
obj.loadVizEvents(d.outputs(), true);
obj.applyVizSettings("events");
obj.Viewer.render();
end
