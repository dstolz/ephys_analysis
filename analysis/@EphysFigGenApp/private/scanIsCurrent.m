function tf = scanIsCurrent(obj, S, opts)
%scanIsCurrent  Whether the datasets listed are the scan of the source S (a config's Source); an action stops when not.
%   TF = scanIsCurrent(OBJ, S) is true when the runner's datasets were
%   scanned from what S names now: scannedSource of S equals that of the
%   Source the last scan read (ScannedSource). A change of the ticks, the
%   filter, the signals' rates or filters is no change of the source. No
%   runner: false (nothing is scanned).
%
%   TF = scanIsCurrent(OBJ, S, Action=TITLE, Again=TEXT), for Run, Plan,
%   Generate selected figure and Test report: when the datasets listed
%   are another source's (the root, output root, name pattern, recordings
%   or folders changed since the scan), the action stops there
%   (stopAction: an alert titled TITLE that says to press Scan and then
%   TEXT again, the Data tab, Scan focused): the old datasets must not be
%   drawn and written under the new source's folders, with a config that
%   names the new source. The Data tab's scan line says the same
%   (showScanLabel). They stop too, with an alert to press Scan, while the
%   config names datasets the datasets listed lack (TickedNotListed: a
%   config opened while its project could not be scanned, the listing
%   the last scan's): the run would draw only the listed ones and record
%   a config that names the others. Without Action (gatherSourceSection,
%   showScanLabel) those keys are no change of the source.
%
%   See also scannedSource, showScanLabel, gatherSourceSection.
arguments
    obj
    S (1,1) struct
    opts.Action (1,1) string = ""
    opts.Again (1,1) string = ""
end
if isempty(obj.Runner)
    tf = false;
elseif isempty(fieldnames(obj.ScannedSource))
    tf = true;   % no scan recorded to compare with
else
    tf = isequaln(scannedSource(S), scannedSource(obj.ScannedSource));
end
if opts.Action == ""; return; end
again = opts.Again;
if again == ""; again = lower(opts.Action); end
if tf
    if isempty(obj.TickedNotListed); return; end
    tf = false;   % the config names datasets the last listing does not have: a run would leave them out, its record name them
    keys = obj.TickedNotListed;
    stopAction(obj, opts.Action, "The config names datasets the last scan did not list (" + strjoin(keys(1:min(3, end)), ", ") + ...
        ternary(numel(keys) > 3, sprintf(" and %d more", numel(keys) - 3), "") + "), so a run would leave them out and nothing was done." + ...
        newline + "Press Scan to list them, then " + again + " again.", Tab=obj.TabData, Control=obj.ScanButton, ...
        Status="The config names datasets the last scan did not list: press Scan, then " + again + " again.");
    return
end
stopAction(obj, opts.Action, "The source on the Data tab changed since the last scan (its root, output root, name pattern, " + ...
    "recordings or folders), so the datasets listed are not its datasets and nothing was done." + newline + ...
    "Press Scan to list them, then " + again + " again.", Tab=obj.TabData, Control=obj.ScanButton, ...
    Status="The source changed since the last scan: press Scan, then " + again + " again.");
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
