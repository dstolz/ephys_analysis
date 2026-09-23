function routeFigureInput(obj)
%routeFigureInput  Share the figure's wheel and key callbacks between the
%   plots that take them. This wraps whatever WindowScrollWheelFcn /
%   WindowKeyPressFcn / WindowKeyReleaseFcn is installed (kept in
%   FigInput): while the Artifacts tab is showing, wheel turns and key
%   presses go to onArtViewInput, while the Visualize tab is showing to
%   onVizInput (what either does not take is dropped), and on any other
%   tab to the handler wrapped. Key releases always go to it. Presses and
%   releases also keep ArtView.mods, the modifiers held, as wheel events
%   carry none. Called when the Artifacts tab is built; wrapping itself is
%   a no-op.
%
%   See also onArtViewInput, onVizInput.

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
if kind ~= "release" && isvalid(obj.Tabs)
    if obj.Tabs.SelectedTab == obj.TabArtifacts
        obj.onArtViewInput(kind, evt);
        return
    elseif obj.Tabs.SelectedTab == obj.TabVisualize
        obj.onVizInput(kind, evt);
        return
    end
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
