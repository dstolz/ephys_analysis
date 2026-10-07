function onProbeClick(obj, evt)
%onProbeClick  A click on the probe picture: select the nearest site.
%   A shift-click also adds the site to the kcoords Sites list.
kind = "normal";
try
    kind = string(obj.Fig.SelectionType);
catch
end
if kind == "alt"
    return
end
P = obj.ProbeSites;
if isempty(P.Site)
    return
end
pt = evt.IntersectionPoint;
[~, k] = min(hypot(P.X - pt(1), P.Y - pt(2)));
if kind == "extend"
    txt = strip(string(obj.KCoordSitesField.Value));
    if txt == ""
        txt = string(P.Site(k));
    else
        txt = txt + ", " + P.Site(k);
    end
    obj.KCoordSitesField.Value = char(txt);
end
obj.select("site", P.Site(k));
end
