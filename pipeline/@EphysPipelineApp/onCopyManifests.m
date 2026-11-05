function [copied, msg] = onCopyManifests(obj, idx, opts)
%onCopyManifests  Put datasets' manifest files on the clipboard (Tools panel: Copy manifests).
%   obj.onCopyManifests() puts the <Name>_manifest.json of each of the Tools
%   panel's datasets (toolTargets) on the Windows clipboard as files, ready
%   to paste into a folder, an e-mail or a chat (copyFilesToClipboard). An
%   alert then names each file the clipboard holds, read back from it, and
%   each that is not there with why: a manifest that could not be written
%   (a dataset without one gets it written first, as onViewManifest does),
%   or a file the clipboard did not take. The status bar says how many.
%   obj.onCopyManifests(IDX) copies those of datasets IDX.
%
%   [COPIED, MSG] = ...: the manifest files on the clipboard and the
%   alert's text.
%
%   Name-value: Clipboard, the function that writes the clipboard and
%   returns the files it holds (default @copyFilesToClipboard). Tests pass a
%   stand-in, so a run leaves the user's clipboard alone.
%
%   See also copyFilesToClipboard, EphysPipelineApp.onOpenTool,
%   EphysPipelineApp.toolTargets.
arguments
    obj (1,1) EphysPipelineApp
    idx (1,:) double = obj.toolTargets()
    opts.Clipboard (1,1) function_handle = @copyFilesToClipboard
end
title = "Copy manifests";
copied = strings(0, 1);
msg = "";
if isempty(obj.Project) || isempty(idx) || any(idx < 1 | idx > obj.Project.NumDatasets)
    obj.alertNoProject(title);
    return
end

files = strings(0, 1);
failed = strings(0, 1);
for i = idx
    d = obj.Project.Datasets(i);
    [ok, why] = ensureManifest(d);
    if ok
        files(end + 1, 1) = string(d.manifestFile()); %#ok<AGROW>
    else
        failed(end + 1, 1) = d.Name + ": no manifest, and none could be written: " + why; %#ok<AGROW>
    end
end

if ~isempty(files)
    try
        copied = reshape(string(opts.Clipboard(files)), [], 1);
    catch ME
        msg = "The clipboard could not be written, so no manifest was copied: " + ME.message;
        uialert(obj.Fig, msg, title, "Icon", "error");
        obj.setStatus("No manifest was copied to the clipboard.", "");
        return
    end
end
notTaken = files(~ismember(lower(files), lower(copied)));
failed = [failed; notTaken + ": the clipboard did not take it"];

n = numel(copied);
if n == 0
    msg = "No manifest file was copied to the clipboard.";
    icon = "error";
else
    msg = sprintf("%s copied to the clipboard. Paste them into a folder, an e-mail or a chat.", ...
        plural(n, "manifest file")) + newline + newline + listed(copied);
    icon = "success";
end
if ~isempty(failed)
    msg = msg + newline + newline + "Not copied:" + newline + listed(failed);
    if n > 0; icon = "warning"; end
end
uialert(obj.Fig, msg, title, "Icon", icon);
if n == 1
    obj.setStatus("Copied " + copied + " to the clipboard.", "");
else
    obj.setStatus("Copied " + plural(n, "manifest file") + " to the clipboard.", "");
end
end


function s = plural(n, noun)
s = sprintf("%d %s", n, noun);
if n ~= 1; s = s + "s"; end
end


function s = listed(lines)
%listed  One "• line" per item; past 20 the rest are counted.
maxShown = 20;
s = strjoin("• " + lines(1:min(end, maxShown)), newline);
if numel(lines) > maxShown
    s = s + newline + sprintf("... and %d more", numel(lines) - maxShown);
end
end
