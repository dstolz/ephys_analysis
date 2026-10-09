function N = drawNote(h, note, style)
%drawNote  A plot's descriptive text: create it, tagged "note" (renderPlot).
%   N = drawNote(H, NOTE, STYLE) draws the text of the note settings NOTE
%   (defaults("Note")) on the plot a renderer drew (H, its result: H.layout
%   or H.axes), with the plot's STYLE.FontSize unless the note has its own.
%   A plot in a tiled layout gets a hidden axes beside it (Tag "noteHost",
%   covering the layout's place, owned by the layout) that holds the text,
%   so the text can sit outside the tiles; a plot that is one axes gets the
%   text in the axes, in normalized units. Either way the text is tagged
%   with the role "note", so the aesthetics editor and the designs reach it.
%
%   N.text is the text object ([] without a note), N.host the hidden axes,
%   N.layout the tiled layout, N.rules the note's own looks as aesthetics
%   rules (renderPlot applies them after the design's and the user's, so the
%   note's settings win over a design). placeNote positions the text once
%   the rules have been applied. A note an earlier draw left on the same
%   layout is removed; a note without text draws nothing.
%
%   See also placeNote, renderPlot, EphysAnalysisConfig.defaults.

N = struct('text', gobjects(0), 'host', gobjects(0), 'layout', [], 'rules', PlotAesthetics.emptyRules());
tl = h.layout;
haveLayout = ~isempty(tl) && isgraphics(tl);
if haveLayout; clearNote(tl); end
words = strip(string(note.text), 'right');
if strtrim(words) == ""; return; end
if ~haveLayout && (isempty(h.axes) || ~isgraphics(h.axes(1))); return; end

fs = style.FontSize;
if isfinite(note.fontSize); fs = note.fontSize; end
weight = 'normal'; if note.bold; weight = 'bold'; end
angle = 'normal'; if note.italic; angle = 'italic'; end
args = {'FontSize', fs, 'FontWeight', weight, 'FontAngle', angle, 'Interpreter', char(note.interpreter), ...
    'HorizontalAlignment', char(note.align), 'VerticalAlignment', char(note.valign), ...
    'Rotation', note.rotation, 'Margin', 4, 'Clipping', 'off'};
lines = cellstr(splitlines(words));
if haveLayout
    parent = tl.Parent;
    base = [0 0 1 1];
    if isappdata(tl, 'NoteBase')
        base = getappdata(tl, 'NoteBase');
    elseif strcmp(tl.Units, 'normalized')
        base = tl.OuterPosition;
        setappdata(tl, 'NoteBase', base);
    end
    host = axes(parent, 'Units', 'normalized', 'PositionConstraint', 'innerposition', 'Position', base, ...
        'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none', 'XLim', [0 1], 'YLim', [0 1], ...
        'Tag', 'noteHost');
    setappdata(host, 'NoteOwner', tl);
    N.host = host;
    N.layout = tl;
    N.text = text(host, 0.5, 0.5, lines, args{:});
else
    N.text = text(h.axes(1), 0.5, 0.5, lines, 'Units', 'normalized', args{:});
end
tagPart(N.text, "note");

rules = N.rules;
rules = addRule(rules, "FontName", strtrim(string(note.fontName)), @(v) ~ismember(lower(v), ["" "auto"]));
rules = addRule(rules, "Color", colorOf(note.color));
rules = addRule(rules, "BackgroundColor", colorOf(note.background));
if isfinite(note.fontSize); rules = addRule(rules, "FontSize", note.fontSize); end
N.rules = rules;
end


function clearNote(tl)
%clearNote  Remove the hidden axes an earlier draw left beside the layout TL and give TL its place back.
parent = tl.Parent;
old = findall(parent, '-depth', 1, 'Type', 'axes', 'Tag', 'noteHost');
for k = 1:numel(old)
    if isappdata(old(k), 'NoteOwner') && isequal(getappdata(old(k), 'NoteOwner'), tl)
        delete(old(k));
    end
end
if isappdata(tl, 'NoteBase') && strcmp(tl.Units, 'normalized')
    tl.OuterPosition = getappdata(tl, 'NoteBase');
end
end


function rules = addRule(rules, prop, value, keep)
%addRule  Append the note's rule PROP = VALUE unless VALUE is empty (or KEEP says no).
if nargin < 4; keep = @(~) true; end
if isempty(value) || (isstring(value) && ~isscalar(value)) || ~keep(value) || (isstring(value) && value == "")
    return
end
rules(1, end+1) = struct('role', "note", 'group', "", 'property', prop, 'value', value);
end


function c = colorOf(name)
%colorOf  The colour a name or #rrggbb gives; [] for "" or what is not a colour (validate warns).
c = [];
name = strtrim(string(name));
if name == ""; return; end
try
    c = validatecolor(name);
catch
    c = [];
end
end
