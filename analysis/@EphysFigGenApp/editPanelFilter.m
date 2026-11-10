function dlg = editPanelFilter(obj)
%editPanelFilter  The selected panel's Filter dialog (FilterDialog): the filter its signal layers are read through.
%   DLG = obj.editPanelFilter() (Filter... in the figure editor's Analysis
%   section, on a continuous, heat map, spectrum, spectrogram or
%   coherence panel) opens it on the filter the editor shows for the panel
%   (its options.filter), drawn at the rate the panel's first signal layer
%   is read at in the active dataset (its rate on file or Source.Downsample's
%   lower one; 1000 Hz before a scan), with a word on the Data tab's filter
%   of that signal, which runs first. On OK the filter goes into the
%   editor's Filter row and the panel (onConfigChanged "figure", "Filter":
%   an edit like any other, undone with Undo, spread to the other panels
%   selected with it); the panel's signal layers are then read through it,
%   each channel's whole recording filtered before the epochs are cut
%   (figureFor's layer filters, selectChannels' Filter). Cancel changes
%   nothing. [] when no panel that takes a filter is selected. With the
%   dialog open already, that one comes to the front and is returned; it
%   is closed when the editor shows another figure or panel
%   (applyFigureEditor), so an OK cannot land there. In a script:
%     cfg.Figures(k).panels(j).options.filter = SignalFilter.preset("theta");
%
%   See also FilterDialog, SignalFilter, onSignalFilter, showPanelFilter.
dlg = obj.PanelFilterWindow;
if ~isempty(dlg) && isvalid(dlg) && dlg.isOpen()
    if dlg.Fig.Visible == "on"; figure(dlg.Fig); end
    return
end
dlg = [];
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
fig = obj.Config.Figures(k);
p = fig.panels(j);
if ~isfield(p.options, 'filter'); return; end
E = obj.FigureEditor;
f = E.filterText.UserData;
if ~isstruct(f); f = p.options.filter; end
% the rate to draw it at: the panel's first enabled signal layer's, as the figures read it
sig = "";
if ~isempty(p.layers)
    on = [p.layers.enabled] & ismember([p.layers.source], EphysAnalysisConfig.SignalSources);
    if any(on); sig = p.layers(find(on, 1)).source; end
end
[rates, notes] = signalReadRates(obj);
rate = NaN;
note = "";
if sig ~= "" && isfield(rates, sig)
    rate = rates.(sig);
    note = notes.(sig);
elseif sig == ""
    note = "The panel has no signal layer: the filter waits for one (spike layers are not filtered).";
end
if sig ~= ""
    first = SignalFilter.describe(sourceFilters(obj.Config.Source).(sig));
    if first ~= ""; note = strtrim(note + " It is first filtered by the Data tab's Filter...: " + first + "."); end
end
dlg = FilterDialog(f, Rate=rate, RateNote=note, Title="Filter: panel " + p.id + " of " + fig.id, ScriptName="options.filter", ...
    Parent=obj.Fig, Visible=obj.Fig.Visible == "on", OnDone=@(r) applyPanelFilter(obj, r));
obj.PanelFilterWindow = dlg;
obj.PanelFilterTarget = struct('FigureId', fig.id, 'PanelId', p.id);
end


function applyPanelFilter(obj, r)
%applyPanelFilter  The dialog closed: R (the panel's new filter) into the editor's Filter row and the panel, or nothing ([]).
if ~isvalid(obj); return; end
obj.PanelFilterWindow = [];
if isempty(r); return; end
k = obj.SelectedFigure;
j = obj.SelectedPanel;
T = obj.PanelFilterTarget;
F = obj.Config.Figures;
if k < 1 || k > numel(F) || F(k).id ~= followedFigureId(obj, T.FigureId) || j < 1 || j > numel(F(k).panels) ...
        || F(k).panels(j).id ~= T.PanelId
    return   % the editor shows another panel now (applyFigureEditor closes the dialog first; this is the fallback)
end
showPanelFilter(obj.FigureEditor, r);
obj.onConfigChanged("figure", "Filter");
end
