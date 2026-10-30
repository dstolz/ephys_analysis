function applyExportSection(obj, E)
%applyExportSection  Export section -> Export tab.
E = EphysPipelineConfig.normalizeSection("Export", E);
obj.ExpEnableCheckBox.Value    = logical(E.Enabled);
obj.ExpNWBCheckBox.Value       = any(E.Formats == "nwb");
N = E.NWB;
obj.ExpNWBLocationField.Value  = char(N.Location);
obj.ExpNWBSpeciesField.Value   = char(N.Species);
obj.setDropIfMember(obj.ExpNWBSexDropDown, N.Sex, "Export.NWB.Sex");
obj.ExpNWBAgeField.Value       = char(N.Age);
obj.ExpNWBTimeZoneField.Value  = char(N.TimeZone);
obj.ExpNWBExperimenterField.Value = char(strjoin(N.Experimenter, "; "));
obj.ExpNWBLabField.Value       = char(N.Lab);
obj.ExpNWBInstitutionField.Value = char(N.Institution);
obj.ExpNWBPythonField.Value    = char(N.PythonExe);
obj.ExpNWBCondaField.Value     = char(N.CondaEnv);
obj.ExpNWBInspectCheckBox.Value = logical(N.Inspect);
obj.ExpSignalsField.Value      = char(strjoin(E.Signals, ", "));
obj.ExpUnitsCheckBox.Value     = logical(E.IncludeUnits);
obj.ExpGroupsField.Value       = char(strjoin(E.Groups, ", "));
obj.ExpEventsCheckBox.Value    = logical(E.IncludeEvents);
obj.ExpOutputDirField.Value    = char(E.OutputDir);
obj.ExpOverwriteCheckBox.Value = logical(E.Overwrite);
end
