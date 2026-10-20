function id = autoFigureId(fig)
%autoFigureId  The id a figure's content gives it: its active panel types, then the data it draws.
%   ID = EphysAnalysisConfig.autoFigureId(FIG) names the figure entry FIG
%   by what it holds, as "<types> <data>", e.g. "Raster+PSTH units",
%   "Continuous LFP", "Raster+PSTH+Continuous units+LFP":
%   - <types>: the Short name (panelTypes) of each active panel's type (a
%     panel with an enabled layer), in grid order (by row, then column),
%     each once, joined by "+"; "Blank" when no panel is active. A type
%     panelTypes does not know is named by its type, first letter upper
%     case
%   - <data>: observe.data (unless "dataset"), then each source the
%     active panels' enabled layers read, in that order, each once,
%     joined by "+"; an events layer counts only where it is the data
%     (on an event-trace panel, or drawn as a spike train: eventsAs
%     "train"), not as marks or spans. "dataset" when there is none
%   Only letters, digits, "+" and single spaces are used, so the id is
%   file-name safe. The id is not made unique here: normalizeFigures
%   gives every figure whose autoId is true this id, or "<id> (n)" with
%   the next free n when another figure has it (a figure keeps an id
%   that still fits its content, so an edit elsewhere renames no other
%   figure).
%
%   See also EphysAnalysisConfig.normalizeFigures, EphysAnalysisConfig.duplicateFigure,
%   EphysAnalysisConfig.panelTypes.

T = EphysAnalysisConfig.panelTypes();
types = strings(1, 0);
data = strings(1, 0);
if fig.observe.data ~= "dataset"; data = fig.observe.data; end
P = fig.panels;
if ~isempty(P)
    [~, order] = sortrows([reshape([P.row], [], 1) reshape([P.col], [], 1)]);
    for q = reshape(order, 1, [])
        p = P(q);
        if isempty(p.layers); continue; end
        on = p.layers([p.layers.enabled]);
        if isempty(on); continue; end
        row = T.Type == p.type;
        if any(row)
            types(end+1) = T.Short(row); %#ok<AGROW>
        else
            t = regexprep(p.type, '[^A-Za-z0-9]', '');
            if t == ""; t = "Panel"; end
            types(end+1) = upper(extractBefore(t, 2)) + extractAfter(t, 1); %#ok<AGROW>
        end
        for L = on
            if L.source == "events" && p.type ~= "eventTrace" && L.eventsAs ~= "train"; continue; end   % marks and spans annotate
            data(end+1) = L.source; %#ok<AGROW>
        end
    end
end
data = regexprep(data, '[^A-Za-z0-9]', '');
data = unique(data(data ~= ""), 'stable');
types = unique(types, 'stable');
if isempty(types); types = "Blank"; end
if isempty(data); data = "dataset"; end
id = strjoin(types, "+") + " " + strjoin(data, "+");
end
