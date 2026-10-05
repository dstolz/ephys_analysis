function R = gatherReferenceSection(obj)
%gatherReferenceSection  Reference section from the Artifacts tab's common-reference panel.
R = obj.Config.Reference;
R.Mode    = string(obj.ArtRefDropDown.Value);
R.BadLow  = obj.ArtRefLowField.Value;
R.BadHigh = obj.ArtRefHighField.Value;
end
