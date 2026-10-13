function syncTrialsDerived(obj, preview)
%syncTrialsDerived  The Trials tab's derived-events line and the open Derived events window.
%   obj.syncTrialsDerived() lists the derived events (TrialsDerivedEvents)
%   beside the Derived events button, with each one's interval count on the
%   loaded pairing (or why it cannot be made there), and gives an open
%   DerivedEventsDialog the definitions when they changed elsewhere (a
%   config loaded). obj.syncTrialsDerived(true) also hands that window the
%   loaded pairing to count on (a dataset loaded, re-paired or cleared).
%
%   See also trialsDerived, onTrialsDerivedEvents, DerivedEventsDialog.

if nargin < 2; preview = false; end
if isempty(obj.TrialsDerivedLabel) || ~isvalid(obj.TrialsDerivedLabel)
    return
end
defs = obj.TrialsDerivedEvents;
[~, D, failed, T] = obj.trialsDerived();
if isempty(defs)
    txt = "None. A derived event is a new line from a line's intervals in the trials that meet conditions (e.g. Depth >= -6).";
else
    parts = [defs.Name];
    if ~isempty(obj.TrialsPairing)
        for d = D
            parts(d.index) = parts(d.index) + " (" + d.nIntervals + ")";
        end
        for f = failed
            parts(f.index) = parts(f.index) + " (cannot be made here)";
        end
    end
    txt = strjoin(parts, ", ");
end
obj.TrialsDerivedLabel.Text = txt;
if isempty(failed)
    obj.TrialsDerivedLabel.Tooltip = "";
else
    obj.TrialsDerivedLabel.Tooltip = strjoin([failed.message], newline);
end

dlg = obj.TrialsDerivedDialog;
if isempty(dlg) || ~isvalid(dlg) || ~isvalid(dlg.Fig)
    return
end
if ~isequal(dlg.Defs, defs)
    dlg.setDefinitions(defs);
end
if preview
    P = obj.TrialsPairing;
    if isempty(P)
        dlg.setPreview();
    else
        d = obj.currentDataset();
        name = "";
        if ~isempty(d); name = d.Name; end
        dlg.setPreview(P.events, T, P.trialLine, name);
    end
end
end
