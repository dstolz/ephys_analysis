function ok = onSynthPreview(obj)
%onSynthPreview  Preview: build what Generate would write and plot it.
%   Loads the source when it is not loaded (onSynthLoadSource), runs
%   makeSyntheticRecording with PreviewOnly (nothing is written; the same
%   options as Generate, synthGeneratorArgs, so the spikes shown are the
%   ones written), keeps the result in SynthModel, lists its units and LFP
%   components in the Unit / LFP boxes and draws it (renderSynthPreview).
ok = false;
if isempty(obj.SynthSource) || obj.SynthSourceKey ~= obj.synthSourceKey()
    if ~obj.onSynthLoadSource(); return; end
end
dlg = uiprogressdlg(obj.Fig, "Title", "Synthetic dataset", "Message", "Building the model ...", "Indeterminate", "on");
closer = onCleanup(@() closeDialog(dlg));
try
    args = obj.synthGeneratorArgs();
    T = makeSyntheticRecording("(preview)", args{:}, PreviewOnly=true);
catch ME
    delete(closer);
    obj.SynthModel = [];
    obj.renderSynthPreview();
    obj.SynthStatusLabel.Text = "Cannot preview: " + string(ME.message);
    obj.SynthStatusLabel.FontColor = [0.70 0.15 0.10];
    return
end
delete(closer);
obj.SynthModel = T;
M = T.model;

u = obj.SynthUnitDropDown.Value;
names = [M.units.name];
if isempty(names)
    set(obj.SynthUnitDropDown, "Items", {'(no units)'}, "ItemsData", {0}, "Value", 0);
else
    linked = find([M.units.event] ~= "", 1);
    if isempty(linked); linked = 1; end
    if ~(isnumeric(u) && u >= 1 && u <= numel(names)); u = linked; end
    set(obj.SynthUnitDropDown, "Items", cellstr(names), "ItemsData", num2cell(1:numel(names)), "Value", u);
end
c = obj.SynthLFPDropDown.Value;
names = [M.lfp.name];
if isempty(names)
    set(obj.SynthLFPDropDown, "Items", {'(no LFP)'}, "ItemsData", {0}, "Value", 0);
else
    if ~(isnumeric(c) && c >= 1 && c <= numel(names)); c = 1; end
    set(obj.SynthLFPDropDown, "Items", cellstr(names), "ItemsData", num2cell(1:numel(names)), "Value", c);
end
if obj.SynthTimelineStartField.Value >= T.duration
    obj.SynthTimelineStartField.Value = 0;
end
obj.renderSynthPreview();

nSp = sum(arrayfun(@(q) numel(q.samples), M.units));
msg = sprintf("Preview (%s): %.1f s at %g Hz, %d channels, %d trials, %d unit(s) (%d spikes), %d LFP component(s); about %.0f MB to write.", ...
    T.subject, T.duration, T.Fs, M.nCh, T.nTrials, numel(M.units), nSp, numel(M.lfp), T.bytes / 2^20);
if T.probeSource == "session"
    [~, f, e] = fileparts(T.probeFile);
    msg = msg + " Probe " + f + e + ".";
end
obj.SynthStatusLabel.Text = msg;
obj.SynthStatusLabel.FontColor = [0.3 0.3 0.3];
ok = true;
end


function closeDialog(dlg)
try
    if isvalid(dlg); close(dlg); end
catch
end
end
