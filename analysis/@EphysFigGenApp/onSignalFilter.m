function dlg = onSignalFilter(obj)
%onSignalFilter  The signals' Filter dialog (FilterDialog): the filter each signal is read through by every figure.
%   DLG = obj.onSignalFilter() (the Data tab's Filter... button) opens it
%   on the config's Source.SignalFilter: a filter per signal (LFP, MUA,
%   SPIKE, AUX; picked with its Signal drop-down), each drawn at the rate
%   the figures read that signal in the active dataset once the datasets
%   are scanned (its rate on file, or Source.Downsample's lower one), the
%   signals the enabled figures read marked (the others "no figure reads
%   it"). On OK the filters go into the config (it is then unsaved), the
%   Filters row says them (showSignalFilter), the runner gets them and
%   the preview follows (onConfigChanged "signalfilter"): every figure
%   then reads each signal through its filter, each channel's whole
%   recording filtered before the epochs are cut (figureFor's layer
%   filters; selectChannels' Filter, each filtered column kept for the
%   redraws that follow). No scan is needed. Cancel changes nothing.
%   With the dialog open already, that one comes to the front and is
%   returned. DLG drives it as the clicks do: setSignal, pick, setCutoff,
%   setPhase, ..., ok, cancel. In a script, set the filters directly:
%     cfg.Source.SignalFilter.LFP = SignalFilter.preset("theta");
%
%   See also FilterDialog, SignalFilter, showSignalFilter, onDownsample,
%   editPanelFilter, selectChannels, EphysAnalysisConfig.figureFor.
dlg = obj.SignalFilterWindow;
if ~isempty(dlg) && isvalid(dlg) && dlg.isOpen()
    if dlg.Fig.Visible == "on"; figure(dlg.Fig); end
    return
end
[rates, notes] = signalReadRates(obj);
dlg = FilterDialog(sourceFilters(obj.Config.Source), Signals=DatasetOutputs.SignalTypes, Rates=rates, RateNotes=notes, ...
    Used=figureSignals(obj.Config), Title="Filter signals", ScriptName="Source.SignalFilter", Parent=obj.Fig, ...
    Visible=obj.Fig.Visible == "on", OnDone=@(r) applyFilters(obj, r));
obj.SignalFilterWindow = dlg;
end


function applyFilters(obj, r)
%applyFilters  The dialog closed: R (the new Source.SignalFilter) into the config, or nothing ([]: canceled or unchanged).
if ~isvalid(obj); return; end
obj.SignalFilterWindow = [];
if isempty(r); return; end
cfg = obj.Config;
cfg.Source.SignalFilter = r;
obj.Config = cfg;   % gatherSourceSection starts from obj.Config.Source: the filters stay through every gather
obj.onConfigChanged("signalfilter");
words = FilterDialog.describeSignals(r);
if words == ""
    obj.setStatus("Filters: every signal read as recorded.");
else
    obj.setStatus("Filters: the figures read " + words + ".");
end
end
