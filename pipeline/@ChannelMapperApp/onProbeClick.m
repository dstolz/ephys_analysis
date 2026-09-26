function onProbeClick(obj, evt)
%onProbeClick  A click on the probe picture: select the nearest site.
try
    if string(obj.Fig.SelectionType) == "alt"
        return
    end
catch
end
P = obj.ProbeSites;
if isempty(P.Site)
    return
end
pt = evt.IntersectionPoint;
[~, k] = min(hypot(P.X - pt(1), P.Y - pt(2)));
obj.select("site", P.Site(k));
end
