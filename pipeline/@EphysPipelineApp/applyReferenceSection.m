function applyReferenceSection(obj, R)
%applyReferenceSection  Reference section -> the Artifacts tab's common-reference panel.
%   Values the controls cannot show are reported (setControlValue).
R = EphysPipelineConfig.normalizeSection("Reference", R);
obj.setDropIfMember(obj.ArtRefDropDown, R.Mode, "Reference.Mode");
obj.setControlValue(obj.ArtRefLowField, R.BadLow, "Reference.BadLow");
obj.setControlValue(obj.ArtRefHighField, R.BadHigh, "Reference.BadHigh");
obj.setDropIfMember(obj.ArtRefWCAREstimateDropDown, R.WCAR_Estimate, "Reference.WCAR_Estimate");
obj.setControlValue(obj.ArtRefWCAROrderField, R.WCAR_Order, "Reference.WCAR_Order");
obj.setControlValue(obj.ArtRefWCARAlphaField, R.WCAR_Alpha1k, "Reference.WCAR_Alpha1k");
obj.setControlValue(obj.ArtRefWCARDriftField, R.WCAR_DriftPerSec, "Reference.WCAR_DriftPerSec");
obj.setControlValue(obj.ArtRefWCARHighpassField, R.WCAR_HighpassHz, "Reference.WCAR_HighpassHz");
obj.ArtRefWCARQAutoCheckBox.Value = isnan(R.WCAR_Q);
if ~isnan(R.WCAR_Q)
    obj.setControlValue(obj.ArtRefWCARQField, R.WCAR_Q, "Reference.WCAR_Q");
end
obj.refreshReferencePanel();
end
