function prepareWCARInDialog(d, dlg)
%prepareWCARInDialog  Work out dataset D's weighted CAR state with the progress dialog DLG showing it.
%   With ArtifactConfig.Reference "wcar" the first referenced read of a
%   recording works out the weighted CAR's state (EphysDataset.prepareWCAR,
%   a pass or two over the whole recording) without a word. Called before
%   that read, under the dialog the read is shown with, it does the same
%   work first: DLG (a uiprogressdlg) goes determinate and says which
%   window it is on and the time left ("Weighted CAR: state, window 12/80 ·
%   about 40 s left"), and the read that follows finds the state held. The
%   same calls as the readers make, in the same order (prepareReference,
%   then prepareWCAR), so nothing read changes. Nothing happens for any
%   other reference, or when D holds the state or reads it from
%   <Name>_wcar.mat.
%
%   See also EphysDataset.prepareWCAR, onDetectArtifacts, onPlotVisualization.
if d.referenceMode() ~= "wcar"
    return
end
d.prepareReference();
clock = ProgressClock();
d.prepareWCAR(ProgressFcn=@(done, total, msg) show(dlg, clock, done / max(total, 1), msg));
end


function show(dlg, clock, frac, msg)
if ~isvalid(dlg); return; end
dlg.Indeterminate = "off";
dlg.Value = min(max(frac, 0), 1);
dlg.Message = char(clock.message(msg, frac));
drawnow limitrate;
end
