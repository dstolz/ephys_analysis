function R = gatherReferenceSection(obj)
%gatherReferenceSection  Reference section from the Artifacts tab's common-reference panel.
R = obj.Config.Reference;
R.Mode    = string(obj.ArtRefDropDown.Value);
R.Local   = logical(obj.ArtRefLocalCheckBox.Value);
R.LocalAutoAssign = logical(obj.ArtRefLocalAutoCheckBox.Value);   % the probes' defaults (LocalDefault*) stay as the config has them
R.BadLow  = obj.ArtRefLowField.Value;
R.BadHigh = obj.ArtRefHighField.Value;
R.WCAR_Order       = obj.ArtRefWCAROrderField.Value;
R.WCAR_Alpha1k     = obj.ArtRefWCARAlphaField.Value;
R.WCAR_DriftPerSec = obj.ArtRefWCARDriftField.Value;
R.WCAR_HighpassHz  = obj.ArtRefWCARHighpassField.Value;
R.WCAR_Estimate    = string(obj.ArtRefWCAREstimateDropDown.Value);
R.WCAR_Q = NaN;   % automatic
if ~obj.ArtRefWCARQAutoCheckBox.Value
    R.WCAR_Q = obj.ArtRefWCARQField.Value;
end
end
