function onBrowseAnalysisConfig(obj)
%onBrowseAnalysisConfig  Choose the analysis config (Analysis.ConfigFile).
%   Starts at the one chosen, else the config the analysis app saved or
%   opened last, else the project root.
start = string(strtrim(obj.AnaConfigField.Value));
if start == "" || ~isfile(start)
    start = "";
    if AppPrefs.ispref('EphysAnalysisApp', 'LastConfigFile')
        start = string(AppPrefs.getpref('EphysAnalysisApp', 'LastConfigFile'));
    end
end
if start == "" || ~isfile(start)
    start = string(obj.RootPathField.Value);
    if start == "" || ~isfolder(start); start = string(pwd); end
end
[f, p] = uigetfile({'*.json', 'Analysis config (*.json)'}, "Choose an analysis config", char(start));
figure(obj.Fig);
if isequal(f, 0); return; end
obj.AnaConfigField.Value = fullfile(p, f);
obj.onAnalysisControlsChanged("file");
end
