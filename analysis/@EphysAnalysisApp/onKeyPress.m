function onKeyPress(obj, evt)
%onKeyPress  The figure's key presses: on the Figures tab the editor's supersections and sections, the search field, the columns, the panels and the observations.
%   EVT is the WindowKeyPressFcn event (Key, Modifier, Character). Only
%   with the Figures tab showing (but Escape during a drag); Cmd instead of
%   Ctrl on a Mac; a digit on the digit row or the number pad:
%     Alt+1 to Alt+3        a supersection: Figure, Panel, Look
%                           (gotoFigureSuper; Option on a Mac)
%     Ctrl+1 to Ctrl+9, 0   a section, named in its header (formLayout):
%                           the first ten, Observations to Text note
%                           (gotoFigureSection)
%     Ctrl+F                the search field (its matches: onFigureSearch)
%     F6, Shift+F6          the next or previous column: the figure list,
%                           the editor, the preview's controls
%                           (focusFigurePane)
%     Ctrl+], Ctrl+[        the next or previous panel of the figure, in
%                           its panel order, round at the ends
%     Ctrl+Alt+arrows       the panel above, below, left or right of the
%                           selected one (stepFigurePanel)
%     Page Up, Page Down    the previous and next observation
%                           (onFigureObservationStep), left alone while a
%                           preview computes or draws
%     Ctrl+Shift+Z          redo the last edit undone (onUndoRedo); Ctrl+Z
%                           and Ctrl+Y are the Edit menu's accelerators,
%                           not keys of this function
%   While a search is under way (FigureSearchState: typed in the field, or
%   a match picked in its list), Enter goes to the match picked (else the
%   first) with the focus on its control, Down and Up (after typing) pick
%   another match, and Escape clears the search (gotoFigureRow). Escape,
%   while a panel is dragged in the schematic, cancels the drag
%   (cancelSchematicDrag), on any tab. A chord with more modifiers than
%   these is left alone (AltGr is Ctrl+Alt on Windows: a digit or a letter
%   with it is a character, not a key of the app's).
key = string(evt.Key);
if key == "escape" && ~isempty(obj.FigureDrag)
    obj.cancelSchematicDrag();   % a panel dragged in the Figures tab's schematic stays where it was
    return
end
if obj.Tabs.SelectedTab ~= obj.TabFigures; return; end
mods = string(evt.Modifier);
ctrl = any(ismember(mods, ["control" "command"]));
alt = any(mods == "alt");
shift = any(mods == "shift");
bare = isempty(mods);
digit = erase(key, "numpad");
isDigit = strlength(digit) == 1 && isstrprop(digit, 'digit');

% the search: Enter, Down / Up and Escape while it is under way
if bare && obj.FigureSearchState ~= "" && ismember(key, ["return" "escape" "downarrow" "uparrow"])
    lb = obj.FigureSearchList;
    switch key
        case "return"
            v = lb.Value;
            if ~(isnumeric(v) && isscalar(v) && v >= 1) && ~isempty(lb.ItemsData); v = lb.ItemsData(1); end
            if isnumeric(v) && isscalar(v) && v >= 1; obj.gotoFigureRow(v); end
            return
        case "escape"
            obj.FigureSearchField.Value = '';
            obj.onFigureSearch("");
            try focus(obj.FigureSearchField); catch; end
            return
        otherwise
            if obj.FigureSearchState == "typing" && isnumeric(lb.ItemsData) && ~isempty(lb.ItemsData) && lb.ItemsData(1) >= 1
                at = find(lb.ItemsData == lb.Value, 1);
                if isempty(at); at = 0; end
                at = min(max(at + 1 - 2 * (key == "uparrow"), 1), numel(lb.ItemsData));
                lb.Value = lb.ItemsData(at);
                obj.gotoFigureRow(lb.Value, Focus=false);   % the editor shows it; typing goes on in the field
                return
            end
    end
end
if bare && any(key == ["pageup" "pagedown"])
    if ~ismember(obj.FigurePreviewState, ["computing" "drawing"])
        obj.onFigureObservationStep(1 - 2 * (key == "pageup"));
    end
    return
end
if ctrl && shift && ~alt && key == "z"
    obj.onUndoRedo("redo");
    return
end
if key == "f6" && ~ctrl && ~alt
    obj.focusFigurePane(1 - 2 * shift);
    return
end
if alt && ~ctrl && ~shift && isDigit
    u = str2double(digit);
    if u >= 1 && u <= numel(obj.FigureSupers); obj.gotoFigureSuper(obj.FigureSupers(u).Name); end
    return
end
if ctrl && alt && ~shift && ismember(key, ["uparrow" "downarrow" "leftarrow" "rightarrow"])
    obj.stepFigurePanel(erase(key, "arrow"));
    return
end
if ~ctrl || alt || shift; return; end
if key == "f"
    obj.FigureSearchState = "typing";
    try focus(obj.FigureSearchField); catch; end
    return
end
if ismember(key, ["rightbracket" "bracketright" "]"]) || isequal(evt.Character, ']')
    obj.stepFigurePanel("next");
    return
end
if ismember(key, ["leftbracket" "bracketleft" "["]) || isequal(evt.Character, '[')
    obj.stepFigurePanel("previous");
    return
end
if ~isDigit; return; end
S = obj.FigureSections;
i = find([S.Key] == digit, 1);
if ~isempty(i); obj.gotoFigureSection(S(i).Name); end
end
