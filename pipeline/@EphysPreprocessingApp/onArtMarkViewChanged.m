function onArtMarkViewChanged(obj)
%onArtMarkViewChanged  The marking view moved: show its view on the status line.
%   Called by obj.ArtMarkViewer after every draw and every pan inside what
%   is drawn (EphysTraceViewer.ViewChangedFcn), and after a period is marked
%   or marking is switched, so it only sets text. The line names the
%   dataset and the time shown, how many manual periods it has, and
%   whether marking is on; syncArtMark words the line itself while no
%   dataset is loaded.
%
%   See also syncArtMark, onArtMarkInput.

v = obj.ArtMarkViewer;
d = obj.ArtMarkDataset;
if isempty(v) || ~isvalid(v) || isempty(obj.ArtMarkStatusLabel) || ~isvalid(obj.ArtMarkStatusLabel) ...
        || isempty(d) || ~isvalid(d)
    return
end
txt = sprintf("%s | %.4g - %.4g s of %.4g s | %d manual period(s)", d.Name, v.TStart, ...
    v.TStart + v.TWidth, v.TotalDuration, size(d.ManualArtifacts, 1));
if obj.ArtMarkMode
    txt = txt + " | Marking is on: drag to mark a period, click a marked one to remove it.";
end
R = v.LastRender;
if R.error ~= ""
    txt = txt + " | " + R.error;
elseif ~isempty(R.notes)
    txt = txt + " | " + strjoin(R.notes, "; ");
end
obj.ArtMarkStatusLabel.Text = txt;
end
