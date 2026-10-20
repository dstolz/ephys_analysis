function p = figureSearchPath(obj, e)
%figureSearchPath  Where a search entry (figureSearchIndex) sits, as listed: "Panel > PSTH options > Bin (ms)".
%   The supersection's title, the section's title as it reads now, the
%   row's label; a supersection or a section alone stops there. The rows
%   above the supersections (Id, Title, Enabled) read "Figure > Id".
U = obj.FigureSupers;
parts = strings(1, 0);
if e.Super ~= ""
    parts(end+1) = U([U.Name] == e.Super).Title;
elseif e.Row ~= -2
    parts(end+1) = "Figure";
end
if e.Section ~= "" && e.Row ~= 0
    S = obj.FigureSections([obj.FigureSections.Name] == e.Section);
    if S.Title ~= ""; parts(end+1) = S.Title; end
end
if e.Row ~= -2
    if e.Row == 0
        S = obj.FigureSections([obj.FigureSections.Name] == e.Section);
        parts(end+1) = S.Title;
    else
        parts(end+1) = e.Label;
    end
end
if isempty(parts); parts = e.Label; end
p = strjoin(parts, " > ");
end
