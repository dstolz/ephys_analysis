function p = figureSearchPath(obj, e)
%figureSearchPath  Where a search entry (figureSearchIndex) sits, as listed: "Panel > PSTH options > Bin (ms)".
%   The supersection's title, the section's title as it reads now, the
%   title of the sub-heading the row is under (formSubheading), the row's
%   label ("Figure > Observations > Response test > Windows (s)"); a
%   supersection, a section or a sub-heading alone stops there. The rows
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
        if e.Row > 0
            S = obj.FigureSections([obj.FigureSections.Name] == e.Section);
            owner = formGroup(S, e.Row);
            if owner > 0; parts(end+1) = S.SubTitle(owner); end
        end
        parts(end+1) = e.Label;
    end
end
if isempty(parts); parts = e.Label; end
p = strjoin(parts, " > ");
end
