function onSynthGenerate(obj)
%onSynthGenerate  Generate...: confirm where and how much, then write (generateSynthetic).
%   Loads the source when needed, checks the design against it, asks for
%   an output folder when there is none, and confirms the folder and the
%   size (an existing synthetic dataset there is replaced only after a
%   second confirmation; any other non-empty folder is refused).
if obj.SynthSourceDropDown.Value ~= "task" && (isempty(obj.SynthSource) || obj.SynthSourceKey ~= obj.synthSourceKey())
    if ~obj.onSynthLoadSource(); return; end
end
if obj.synthOutputRoot() == ""
    obj.onSynthDesign("browseOutput");
    if obj.synthOutputRoot() == ""; return; end
end
try
    [args, acq] = obj.synthGeneratorArgs();
catch ME
    uialert(obj.Fig, string(ME.message), "Generate synthetic dataset");
    return
end
[lines, params] = obj.synthSourceLists();
issues = obj.gatherSynthDesign().validate(lines, params, obj.SynthChannelsField.Value, obj.SynthFsField.Value);
if ~isempty(issues)
    uialert(obj.Fig, "The design cannot be generated:" + newline + strjoin("- " + issues, newline), ...
        "Generate synthetic dataset");
    return
end
[folder, why] = obj.synthOutputFolder(acq);
if folder == ""
    uialert(obj.Fig, why, "Generate synthetic dataset");
    return
end

% size: the amplifier data at int16 plus the digital word, from the preview or the source's length
dur = NaN;
if ~isempty(obj.SynthModel); dur = obj.SynthModel.duration; end
if isnan(dur) && ~isempty(obj.SynthSource) && isfield(obj.SynthSource, 'duration'); dur = obj.SynthSource.duration; end
if obj.SynthMaxDurField.Value > 0 && obj.SynthSourceDropDown.Value ~= "task"; dur = min(dur, obj.SynthMaxDurField.Value); end
sizeText = "";
if isfinite(dur)
    mb = 2 * dur * obj.SynthFsField.Value * (obj.SynthChannelsField.Value + 1) / 2^20;
    sizeText = sprintf(" About %.0f s, %.0f MB.", dur, mb);
end

replace = false;
if isfolder(folder) && numel(dir(folder)) > 2
    if isempty(dir(fullfile(folder, '*_synthetic.json')))
        uialert(obj.Fig, folder + newline + "exists and is not a synthetic dataset. Pick another output folder or subject.", ...
            "Generate synthetic dataset");
        return
    end
    sel = uiconfirm(obj.Fig, folder + newline + "already holds a synthetic dataset. Replace it?", ...
        "Generate synthetic dataset", "Options", {'Replace', 'Cancel'}, "DefaultOption", 2, "CancelOption", 2);
    if ~strcmp(sel, 'Replace'); return; end
    replace = true;
end
src = "the built-in task";
if obj.SynthSourceDropDown.Value ~= "task"; src = "the Epsych2 session of " + obj.SynthSource.source; end
sel = uiconfirm(obj.Fig, "Write a synthetic dataset with events from " + src + " to" + newline + folder + newline + sizeText, ...
    "Generate synthetic dataset", "Options", {'Generate', 'Cancel'}, "DefaultOption", 1, "CancelOption", 2);
if ~strcmp(sel, 'Generate'); return; end
obj.generateSynthetic(Replace=replace, Args=args, Folder=folder);
end
