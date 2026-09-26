function onCascadeChanged(obj, which)
%onCascadeChanged  A probe / package / headstage dropdown, a filter or the count changed.
if obj.Applying
    return
end
switch which
    case {"probeFilter", "hsFilter"}
        obj.fillCascade();
    case "probe"
        obj.selectProbe(string(obj.ProbeDrop.Value));
    case "package"
        obj.selectPackage(string(obj.PackageDrop.Value));
    case "headstage"
        obj.selectHeadstage(string(obj.HsDrop.Value));
    case "count"
        obj.selectHeadstage(obj.HeadstageId, obj.HsCountSpinner.Value);
end
end
