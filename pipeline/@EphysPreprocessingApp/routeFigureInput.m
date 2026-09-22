function routeFigureInput(obj)
%routeFigureInput  Share the figure's wheel and key callbacks with the
%   Artifacts tab's plot. The Visualize viewer (MultiChannelViewer) takes
%   the figure's WindowScrollWheelFcn / WindowKeyPressFcn /
%   WindowKeyReleaseFcn when it is first plotted, so this wraps whatever is
%   installed (kept in FigInput): while the Artifacts tab is showing, wheel
%   turns and key presses go to onArtViewInput (what it does not take is
%   dropped), and on any other tab to the handler wrapped. Key releases
%   always go to it. Presses and releases also keep ArtView.mods, the
%   modifiers held, as wheel events carry none. Called when the Artifacts
%   tab is built and again after the viewer attaches its callbacks
%   (onPlotVisualization); wrapping itself is a no-op.
%
%   See also onArtViewInput, onPlotVisualization, MultiChannelViewer.

fig = obj.Fig;
kinds = ["scroll", "key", "release"];
props = {'WindowScrollWheelFcn', 'WindowKeyPressFcn', 'WindowKeyReleaseFcn'};
for i = 1:numel(kinds)
    f = fig.(props{i});
    if ~isRouter(f)
        obj.FigInput.(kinds(i)) = f;
    end
    kind = kinds(i);
    fig.(props{i}) = @(src, evt) routeInput(obj, kind, src, evt);
end
end


function routeInput(obj, kind, src, evt)
if kind ~= "scroll"
    obj.ArtView.mods = string(evt.Modifier);
end
if kind ~= "release" && isvalid(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabArtifacts
    obj.onArtViewInput(kind, evt);
    return
end
prev = obj.FigInput.(kind);
if isa(prev, 'function_handle')
    prev(src, evt);
elseif iscell(prev) && ~isempty(prev)
    prev{1}(src, evt, prev{2:end});
end
end


function tf = isRouter(f)
tf = isa(f, 'function_handle') && contains(func2str(f), "routeInput(");
end
