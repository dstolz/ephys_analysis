function updateTitle(obj)
%updateTitle  "Channel mapper - <mapping>" (or the package and headstage when unsaved).
if isempty(obj.Fig) || ~isvalid(obj.Fig)
    return
end
t = "Channel mapper";
if obj.MappingName ~= ""
    t = t + " - " + obj.MappingName;
elseif obj.PackageId ~= "" && obj.HeadstageId ~= ""
    t = t + " - " + obj.PackageId + " on " + obj.HeadstageId + " (unsaved)";
end
if ~isempty(obj.App)
    t = t + "  [Preprocessing app]";
end
obj.Fig.Name = char(t);
end
