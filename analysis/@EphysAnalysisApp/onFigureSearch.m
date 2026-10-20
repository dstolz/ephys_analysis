function onFigureSearch(obj, text)
%onFigureSearch  List the figure editor's settings that match TEXT under the search field: "Supersection > Section > Row".
%   The search field over the editor calls this as you type (Ctrl+F goes
%   there). TEXT's words, in any order and case, must each be part of a
%   row's label, its other labels and texts, or its controls' tooltips
%   (FigureSearchIndex, made from the rows as built: figureSearchIndex);
%   the supersections and the sections' titles match too. Labels that
%   start with the text as a word come first ("bin": Bin (ms) before
%   Binding), then labels that start with it, then labels holding every
%   word, then the rest; within each, the rows the figure shows before
%   those it hides, then the editor's order; at most 40 are listed. A section
%   is named by its title as it reads now ("PSTH options"), and a row the
%   figure does not show is listed too (going there says why). Blank TEXT
%   hides the list. While the list shows, Enter goes to the match picked
%   (else the first) and Down / Up pick another (onKeyPress); a click goes
%   there (gotoFigureRow). The status bar counts the matches.
text = strtrim(string(text));
lb = obj.FigureSearchList;
grid = lb.Parent;
X = obj.FigureSearchIndex;
if text == "" || isempty(X)
    set(lb, "Items", {}, "ItemsData", [], "Visible", "off", "UserData", []);
    grid.RowHeight{2} = 0;
    obj.FigureSearchState = "";
    return
end
words = split(lower(text)).';
words = words(words ~= "");
q = lower(text);
score = zeros(1, numel(X));
for i = 1:numel(X)
    if ~all(arrayfun(@(w) contains(X(i).Words, w), words)); continue; end
    if ~isempty(regexp(X(i).LabelWords, "^" + regexptranslate('escape', q) + "(\W|$)", 'once'))
        score(i) = 4;   % the label starts with the text as a whole word: "bin" finds Bin (ms) before Binding
    elseif startsWith(X(i).LabelWords, q)
        score(i) = 3;
    elseif all(arrayfun(@(w) contains(X(i).LabelWords, w), words))
        score(i) = 2;
    else
        score(i) = 1;
    end
    score(i) = score(i) + 0.5 * shows(obj, X(i));   % what the figure shows before what it hides, alike otherwise
end
hit = find(score > 0);
[~, o] = sortrows([-score(hit).' hit.']);
hit = hit(o);
n = numel(hit);
hit = hit(1:min(n, 40));
if isempty(hit)
    set(lb, "Items", "No setting matches """ + text + """", "ItemsData", 0, "Value", 0, "Visible", "on", "UserData", []);
    grid.RowHeight{2} = 26;
    obj.FigureSearchState = "typing";
    obj.setStatus("No setting of the figure editor matches """ + text + """.");
    return
end
paths = strings(1, numel(hit));
for i = 1:numel(hit)
    paths(i) = figureSearchPath(obj, X(hit(i)));
end
set(lb, "Items", paths, "ItemsData", hit, "Value", hit(1), "Visible", "on", "UserData", []);
grid.RowHeight{2} = min(numel(hit), 6) * 20 + 6;
obj.FigureSearchState = "typing";
if n > numel(hit)
    obj.setStatus(sprintf("%d settings match ""%s"" (the first %d listed): Enter goes to the first, a click to any.", n, text, numel(hit)));
else
    obj.setStatus(sprintf("%d setting(s) match ""%s"": Enter goes to the first, a click to any.", n, text));
end
end


function tf = shows(obj, e)
%shows  The entry is shown for the figure now: its section is, and its row (a supersection always).
tf = true;
if e.Section == ""; return; end
S = obj.FigureSections([obj.FigureSections.Name] == e.Section);
tf = S.Visible && (isempty(S.Heights) || any(S.Shown)) && (e.Row <= 0 || S.Shown(e.Row));
end
