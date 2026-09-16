function applyExportSection(obj, E)
%applyExportSection  Export section -> Export tab.
E = EphysPipelineConfig.normalizeSection("Export", E);
obj.ExpEnableCheckBox.Value    = logical(E.Enabled);
obj.ExpChronuxCheckBox.Value   = any(E.Formats == "chronux");
obj.ExpFieldTripCheckBox.Value = any(E.Formats == "fieldtrip");
obj.ExpSignalsField.Value      = char(strjoin(E.Signals, ", "));
obj.ExpUnitsCheckBox.Value     = logical(E.IncludeUnits);
obj.ExpGroupsField.Value       = char(strjoin(E.Groups, ", "));
obj.ExpDetectedCheckBox.Value  = logical(E.IncludeDetected);
obj.ExpEventsCheckBox.Value    = logical(E.IncludeEvents);
obj.ExpBehaviorCheckBox.Value  = logical(E.IncludeBehavior);
obj.ExpValidateCheckBox.Value  = logical(E.Validate);
obj.ExpOutputDirField.Value    = char(E.OutputDir);
obj.setDropIfMember(obj.ExpMatVersionDropDown, E.MatVersion);
obj.ExpOverwriteCheckBox.Value = logical(E.Overwrite);
end
