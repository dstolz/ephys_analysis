function routeFigureInput(obj)
%routeFigureInput  Share the figure's wheel, key and button callbacks between
%   the plots that take them. This wraps whatever WindowScrollWheelFcn /
%   WindowKeyPressFcn / WindowKeyReleaseFcn / WindowButtonDownFcn /
%   WindowButtonUpFcn is installed (kept in FigInput): while the Artifacts
%   tab is showing, wheel turns, key presses and button presses and
%   releases go to onArtViewInput, or to onArtMarkInput when its Mark
%   manual periods view is the one showing; while the Visualize tab is
%   showing the wheel and keys go to onVizInput (what either does not take
%   is dropped), and otherwise to the handler wrapped (the Visualize tab's
%   buttons are its own, onVizButtonDown / onVizButtonUp). Key releases go
%   to onArtViewInput on any tab (letting go of Ctrl ends its bound
%   editing) and then always to the handler wrapped. Presses and releases
%   also keep ArtView.mods, the modifiers held, as wheel events carry
%   none. Called when the Artifacts tab is built; wrapping itself is a
%   no-op.
%
%   See also onArtViewInput, onArtMarkInput, onVizInput.

fig = obj.Fig;
kinds = ["scroll", "key", "release", "down", "up"];
props = {'WindowScrollWheelFcn', 'WindowKeyPressFcn', 'WindowKeyReleaseFcn', ...
    'WindowButtonDownFcn', 'WindowButtonUpFcn'};
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
if kind == "key" || kind == "release"
    obj.ArtView.mods = string(evt.Modifier);
end
if kind == "release"
    obj.onArtViewInput(kind, evt);
elseif isvalid(obj.Tabs)
    if obj.Tabs.SelectedTab == obj.TabArtifacts
        if obj.ArtViewTabs.SelectedTab == obj.ArtTabMark
            obj.onArtMarkInput(kind, evt);
        else
            obj.onArtViewInput(kind, evt);
        end
        return
    elseif obj.Tabs.SelectedTab == obj.TabVisualize && (kind == "scroll" || kind == "key")
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
