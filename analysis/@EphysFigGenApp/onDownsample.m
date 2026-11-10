function dlg = onDownsample(obj)
%onDownsample  The Downsample signals dialog (DownsampleDialog): the rate each signal is brought to before any figure reads it.
%   DLG = obj.onDownsample() (the Data tab's Downsample... button) opens it
%   on the config's Source.Downsample: a rate per signal (LFP, MUA, SPIKE,
%   AUX; blank = the rate on file), each signal's rate on file in the
%   active dataset once the datasets are scanned, the signals the enabled
%   figures read in bold (the others "no figure reads it"), and the band
%   each rate keeps unchanged. On OK the rates go into the config (it is
%   then unsaved), the Signals row says them (showDownsample), the runner
%   gets them and the preview follows (onConfigChanged "downsample"):
%   every figure then reads each signal at its rate, low-pass filtered
%   first so nothing above the new Nyquist folds back into it
%   (figureFor's layer downsample; selectChannels' Rate: resampleSignal,
%   zero phase, flat to 0.38 x the new rate), each resampled column kept
%   for the redraws that follow. No scan is needed. Cancel changes
%   nothing. With the dialog open already, that one comes to the front
%   and is returned. DLG drives it as the clicks do: setRate, clearRates,
%   ok, cancel. In a script, set the rates directly (signals left out keep
%   their rate on file):
%     cfg.Source.Downsample.LFP = 250;
%
%   See also DownsampleDialog, showDownsample, resampleSignal, selectChannels,
%   EphysAnalysisConfig.figureFor.
dlg = obj.DownsampleWindow;
if ~isempty(dlg) && isvalid(dlg) && dlg.isOpen()
    if dlg.Fig.Visible == "on"; figure(dlg.Fig); end
    return
end
fileRates = struct();
name = "";
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1
    try
        src = obj.Runner.source(obj.ActiveIdx);
        fileRates = src.signalFs;
        name = string(src.name);
    catch
        % the rates on file stay unknown: the dialog says so
    end
end
dlg = DownsampleDialog(sourceRates(obj.Config.Source), FileRates=fileRates, Dataset=name, ...
    Ticked=figureSignals(obj.Config), UnusedNote="no figure reads it", UsedBy="the figures", ...
    ScriptName="Source.Downsample", Parent=obj.Fig, Visible=obj.Fig.Visible == "on", ...
    OnDone=@(r) applyRates(obj, r));
obj.DownsampleWindow = dlg;
end


function applyRates(obj, r)
%applyRates  The dialog closed: R (the new Source.Downsample) into the config, or nothing ([]: canceled or unchanged).
if ~isvalid(obj); return; end
obj.DownsampleWindow = [];
if isempty(r); return; end
cfg = obj.Config;
cfg.Source.Downsample = r;
obj.Config = cfg;   % gatherSourceSection starts from obj.Config.Source: the rates stay through every gather
obj.onConfigChanged("downsample");
words = DownsampleDialog.describe(r);
if words == ""
    obj.setStatus("Signals: every signal at its rate on file.");
else
    obj.setStatus("Signals: the figures read " + words + " (anti-aliased).");
end
end
