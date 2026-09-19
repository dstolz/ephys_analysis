function applyExportSection(obj, E)
%applyExportSection  Export section -> Export tab.
E = EphysPipelineConfig.normalizeSection("Export", E);
obj.ExpEnableCheckBox.Value    = logical(E.Enabled);
obj.ExpChronuxCheckBox.Value   = any(E.Formats == "chronux");
obj.ExpFieldTripCheckBox.Value = any(E.Formats == "fieldtrip");
obj.ExpEpochsCheckBox.Value    = any(E.Formats == "epochs");
obj.ExpSignalsField.Value      = char(strjoin(E.Signals, ", "));
obj.ExpUnitsCheckBox.Value     = logical(E.IncludeUnits);
obj.ExpGroupsField.Value       = char(strjoin(E.Groups, ", "));
obj.ExpDetectedCheckBox.Value  = logical(E.IncludeDetected);
obj.ExpEventsCheckBox.Value    = logical(E.IncludeEvents);
obj.ExpValidateCheckBox.Value  = logical(E.Validate);
obj.setDropIfMember(obj.ExpEpochSourceDropDown, E.EpochSource);
obj.ExpEpochLineField.Value    = char(E.EpochLine);
obj.ExpEpochPreField.Value     = E.EpochWindow(1);
obj.ExpEpochPostField.Value    = E.EpochWindow(2);
obj.setDropIfMember(obj.ExpEpochOnsetRuleDropDown, E.EpochOnsetRule);
obj.setDropIfMember(obj.ExpEpochIncompleteDropDown, E.EpochIncomplete);
obj.setDropIfMember(obj.ExpEpochNonFiniteDropDown, E.EpochNonFinite);
obj.setDropIfMember(obj.ExpEpochSpikeBaseDropDown, E.EpochSpikeTimeBase);
obj.setDropIfMember(obj.ExpEpochClassDropDown, E.EpochClass);
obj.ExpOutputDirField.Value    = char(E.OutputDir);
obj.setDropIfMember(obj.ExpMatVersionDropDown, E.MatVersion);
obj.ExpOverwriteCheckBox.Value = logical(E.Overwrite);
end
