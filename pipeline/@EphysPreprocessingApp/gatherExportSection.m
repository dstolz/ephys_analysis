function E = gatherExportSection(obj)
%gatherExportSection  Export section from the Export tab.
E = obj.Config.Export;
E.Enabled = logical(obj.ExpEnableCheckBox.Value);
fm = string.empty(1, 0);
if obj.ExpChronuxCheckBox.Value;   fm(end+1) = "chronux";   end
if obj.ExpFieldTripCheckBox.Value; fm(end+1) = "fieldtrip"; end
if obj.ExpEpochsCheckBox.Value;    fm(end+1) = "epochs";    end
E.Formats = fm;
sig = upper(strtrim(split(string(obj.ExpSignalsField.Value), [",", ";", " "])));
E.Signals = reshape(sig(sig ~= ""), 1, []);
E.IncludeUnits    = logical(obj.ExpUnitsCheckBox.Value);
grp = strtrim(split(string(obj.ExpGroupsField.Value), [",", ";", " "]));
E.Groups = reshape(grp(grp ~= ""), 1, []);
E.IncludeDetected = logical(obj.ExpDetectedCheckBox.Value);
E.IncludeEvents   = logical(obj.ExpEventsCheckBox.Value);
E.Validate        = logical(obj.ExpValidateCheckBox.Value);
E.EpochSource     = string(obj.ExpEpochSourceDropDown.Value);
E.EpochLine       = string(strtrim(obj.ExpEpochLineField.Value));
E.EpochWindow     = [double(obj.ExpEpochPreField.Value), double(obj.ExpEpochPostField.Value)];
E.EpochOnsetRule  = string(obj.ExpEpochOnsetRuleDropDown.Value);
E.EpochIncomplete = string(obj.ExpEpochIncompleteDropDown.Value);
E.EpochNonFinite  = string(obj.ExpEpochNonFiniteDropDown.Value);
E.EpochArtifacts  = string(obj.ExpEpochArtifactsDropDown.Value);
E.EpochSpikeTimeBase = string(obj.ExpEpochSpikeBaseDropDown.Value);
E.EpochClass      = string(obj.ExpEpochClassDropDown.Value);
E.OutputDir  = string(strtrim(obj.ExpOutputDirField.Value));
E.MatVersion = string(obj.ExpMatVersionDropDown.Value);
E.Overwrite  = logical(obj.ExpOverwriteCheckBox.Value);
end
