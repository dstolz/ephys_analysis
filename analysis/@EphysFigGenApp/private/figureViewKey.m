function key = figureViewKey(obj, k)
%figureViewKey  What figure K's preview is drawn from: a preview drawn with another key is out of date.
%   KEY = figureViewKey(OBJ, K) is a struct of
%     figure       Config.Figures(K), its event reference, epoch window and
%                  trial selection taken from Defaults where "default" (as
%                  figureFor resolves them: its panels' "default" are the
%                  figure's), enabled set (a figure that is off is
%                  previewed too)
%     data         the active dataset's key; for a figure across sessions
%                  the keys of the ticked datasets instead (it does not
%                  use the active one)
%     observation  the observation it shows (FigureObservation, by id)
%     downsample   the rates its layers' signals are read at
%                  (Source.Downsample of those signals alone: a field per
%                  signal its layers read, [] = the rate on file)
%     signalFilter the filters its layers' signals are read through
%                  (Source.SignalFilter of those signals alone, a field
%                  each; a panel's own filter is in the figure)
%     generation   FigurePreviewGeneration (a scan reads the data again)
%   refreshFigurePreview keeps the key it drew with (FigurePreviewDrawn,
%   FigureViews.Drawn); previewFigureView and markFigureTree compare. So
%   an edit of one figure leaves the others' previews current, an edit of
%   the defaults reaches the figures that use them, a signal's new rate
%   or filter the figures that read that signal, another dataset or a
%   scan every figure, and an edit undone makes a preview current again.
%   The design is not in it: choosing one redraws every drawn preview in
%   place, the hidden ones too (PlotDesign.redrawAll).
%
%   See also syncFigureView, previewFigureView, markFigureTree.
key = [];
if k < 1 || k > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(k);
fig.enabled = true;
D = obj.Config.Defaults;
if isequal(fig.ref, "default");       fig.ref = D.EventRef;        end
if isequal(fig.window, "default");    fig.window = D.Window;       end
if isequal(fig.selection, "default"); fig.selection = D.Selection; end
data = "";
if ~isempty(obj.Runner)
    if fig.sessions.enabled
        data = reshape(string(obj.Runner.Keys(obj.tickedDatasetIndices())), 1, []);
    elseif obj.ActiveIdx >= 1 && obj.ActiveIdx <= numel(obj.Runner.Keys)
        data = string(obj.Runner.Keys(obj.ActiveIdx));
    end
end
obs = "";
if isa(obj.FigureObservation, 'containers.Map') && isKey(obj.FigureObservation, char(fig.id))
    obs = string(obj.FigureObservation(char(fig.id)));
end
key = struct('figure', fig, 'data', data, 'observation', obs, 'downsample', signalRates(fig, sourceRates(obj.Config.Source)), ...
    'signalFilter', signalRates(fig, sourceFilters(obj.Config.Source)), 'generation', obj.FigurePreviewGeneration);
end


function d = signalRates(fig, rates)
%signalRates  The rates (Source.Downsample), or filters (Source.SignalFilter), of the signals FIG's layers read: a field each, in signal order.
read = strings(1, 0);
for p = reshape(fig.panels, 1, [])
    if ~isempty(p.layers); read = [read, reshape([p.layers.source], 1, [])]; end %#ok<AGROW>
end
d = struct();
for s = reshape(string(fieldnames(rates)), 1, [])
    if ismember(s, read); d.(s) = rates.(s); end
end
end
