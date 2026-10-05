function applyReferenceSection(obj, R)
%applyReferenceSection  Reference section -> the Artifacts tab's common-reference panel.
%   Values the controls cannot show are reported (setControlValue).
R = EphysPipelineConfig.normalizeSection("Reference", R);
obj.setDropIfMember(obj.ArtRefDropDown, R.Mode, "Reference.Mode");
obj.setControlValue(obj.ArtRefLowField, R.BadLow, "Reference.BadLow");
obj.setControlValue(obj.ArtRefHighField, R.BadHigh, "Reference.BadHigh");
obj.refreshReferencePanel();
end
