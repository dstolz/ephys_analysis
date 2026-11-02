function [target, tabName] = issueTarget(step, field)
%issueTarget  Where the app edits what a validation issue is about.
%   [TARGET, TABNAME] = issueTarget(STEP, FIELD) maps an issue of
%   EphysPipelineConfig.validate (its Step and Field columns) to the
%   control that edits it: TARGET is the name of the control's property
%   (a comma separated list for more than one; "" when the field has no
%   control of its own) and TABNAME the property of the tab that holds it
%   ("" for a step the app does not know). The Run tab's issues table
%   opens the control (openSetting), or the tab alone when TARGET is "".
%
%   Behavior issues belong to the Project tab (the search) or the Trials
%   tab (the pairing and the derived events); the Acquisition section
%   (the reader options), the Project tab; the reference, the Artifacts
%   tab; Sorting's runs at once and GPUs, the Run tab, as syncTabStrip
%   attributes them.
%
%   See also openSetting, onIssueActivated, syncTabStrip.
arguments
    step (1,1) string
    field (1,1) string
end
target = "";
switch step
    case "project"
        tabName = "TabProject";
        switch field
            case "Root";                           target = "RootPathField";
            case "OutputRoot";                     target = "OutputRootField";
            case {"NamePattern", "TokenColumns"};  target = "NamePatternField";
            case "Datasets";                       target = "DatasetsTable";
            case "NewDatasetTags";                 target = "AutoTagField";
        end
    case "acquisition"
        tabName = "TabProject";
        switch field
            case "OpenEphys.Recordings";   target = "OERecordingsDropDown";
            case "OpenEphys.RecordNode";   target = "OERecordNodeField";
            case "OpenEphys.EventStream";  target = "OEEventStreamField";
            case "TDT.GainToMicrovolts";   target = "TDTGainField";
        end
    case "behavior"
        tabName = "TabProject";
        switch field
            case "SearchDirs";         target = "BehSearchDirsField";
            case "MaxStartOffsetMin";  target = "BehMaxOffsetField";
            case "TrialLine";          tabName = "TabTrials"; target = "TrialsLineDropDown";
            case "DerivedEvents";      tabName = "TabTrials"; target = "TrialsDerivedButton";
        end
    case "probe"
        tabName = "TabProbe";
        switch field
            case "DefaultProbeFile";            target = "ProbeDefaultField";
            case {"RuleSubjects", "RuleProbes"};  target = "ProbeRulesTable";
        end
    case "parallel"
        tabName = "TabRun";
        switch field
            case "MaxWorkers";  target = "RunMaxWorkersField";
            case "Enabled";     target = "RunParallelCheckBox";
        end
    case "reference"
        tabName = "TabArtifacts";
        switch field
            case "Mode";              target = "ArtRefDropDown";
            case "BadLow";            target = "ArtRefLowField";
            case "BadHigh";           target = "ArtRefHighField";
            case "WCAR_Order";        target = "ArtRefWCAROrderField";
            case "WCAR_Alpha1k";      target = "ArtRefWCARAlphaField";
            case "WCAR_DriftPerSec";  target = "ArtRefWCARDriftField";
            case "WCAR_Q";            target = "ArtRefWCARQField";
            case "WCAR_HighpassHz";   target = "ArtRefWCARHighpassField";
            case "WCAR_Estimate";     target = "ArtRefWCAREstimateDropDown";
        end
    case "artifacts"
        tabName = "TabArtifacts";
        switch field
            case "Method";        target = "ArtMethodDropDown";
            case "Threshold";     target = "ArtThresholdField";
            case "MinChannels";   target = "ArtMinChannelsField";
            case "FilterCutoff";  target = "ArtHighpassField";
            case "Fill";          target = "ArtFillDropDown";
        end
    case "sorting"
        tabName = "TabSorting";
        switch field
            case "PythonExe";      target = "PythonExeField";
            case "Execution";      target = "ExecModeDropDown";
            case "Sorter";         target = "SortSorterDropDown";
            case "KS4ExtraJSON";   target = "ExtraSettingsArea";
            case "SIParams";       target = "SIParamsArea";
            case "MaxConcurrent";  tabName = "TabRun"; target = "RunKSAtOnceSpinner";
            case "Devices";        tabName = "TabRun"; target = "RunKSDevicesField";
            otherwise
                if startsWith(field, "KS4.")   % a Kilosort4 parameter: its row of the Sorting tab
                    target = "ks4." + extractAfter(field, "KS4.");
                end
        end
    case "signals"
        tabName = "TabSignals";
        switch field
            case "LFP_Fs";       target = "ConvLFPFsField";
            case "MUA_Fs";       target = "ConvMUAFsField";
            case "MatVersion";   target = "ConvMatVersionDropDown";
            case "LabelField";   target = "ConvLabelFieldDropDown";
        end
    case "spikes"
        tabName = "TabSpikes";
        switch field
            case "Band";                  target = "SpkBandLoField";
            case "Threshold";             target = "SpkThresholdField";
            case "WindowMs";              target = "SpkWinBeforeField";
            case "ThresholdScope";        target = "SpkThreshScopeDropDown";
            case "Coincidence";           target = "SpkCoincModeDropDown";
            case "CoincidenceRadiusUm";   target = "SpkCoincRadiusField";
            case "CoincidenceJitterMs";   target = "SpkCoincJitterField";
            case "ArtifactMode";          target = "SpkArtifactModeDropDown";
            case "Channels";              target = "SpkChannelsDropDown";
            case "ChannelList";           target = "SpkChannelListField";
            case "Suffix";                target = "SpkSuffixField";
        end
    case "export"
        tabName = "TabExport";
        switch field
            case "Formats";          target = "ExpNWBCheckBox";
            case "NWB.PythonExe";    target = "ExpNWBPythonField";
            case "NWB.Sex";          target = "ExpNWBSexDropDown";
            case "NWB.Age";          target = "ExpNWBAgeField";
            case "NWB.TimeZone";     target = "ExpNWBTimeZoneField";
        end
    case "analysis"
        tabName = "TabAnalysis";
        if field == "ConfigFile"; target = "AnaConfigField"; end
    case "transfer"
        tabName = "TabRun";
        switch field
            case "Enabled";      target = "RunTransferCheckBox";
            case "Destination";  target = "RunTransferDestField";
            case "Method";       target = "RunTransferMethodDropDown";
            case "When";         target = "RunTransferWhenDropDown";
            case "IfExists";     target = "RunTransferIfExistsDropDown";
            case "Verify";       target = "RunTransferHashCheckBox";
        end
    case "analysiscopy"
        tabName = "TabRun";
        target = "RunAnalysisCopyCheckBox";
    otherwise
        tabName = "";
end
end
