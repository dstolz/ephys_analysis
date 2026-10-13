function onBrowseUnitMapping(obj, file)
%onBrowseUnitMapping  Pick the selected session plot's unit-mapping file (a .csv).
%   The Browse... button of the Sessions tab's editor: a file dialog
%   starting in the current file's folder (else the config's). FILE skips
%   the dialog (scripts, tests). The file goes into the editor's Mapping
%   file box and the config (onConfigChanged "sessions"); it is read when
%   the session plot is computed (readUnitMapping).
arguments
    obj (1,1) EphysAnalysisApp
    file (1,1) string = ""
end
k = obj.SelectedSessionPlot;
if k < 1 || k > numel(obj.Config.SessionPlots)
    obj.setStatus("Sessions: add or select a session plot first.");
    return
end
if file == ""
    start = obj.Config.SessionPlots(k).mappingFile;
    if start ~= "" && ~isfolder(fileparts(start)); start = ""; end
    if start == "" && obj.Config.File ~= ""; start = string(fileparts(obj.Config.File)) + filesep; end
    if start == ""; start = string(pwd) + filesep; end
    [f, p] = uigetfile({'*.csv', 'Unit mapping (*.csv)'; '*.*', 'All files'}, 'Unit mapping file', char(start));
    if isequal(f, 0); return; end
    file = string(fullfile(p, f));
end
obj.SessionEditor.mappingFile.Value = char(file);
obj.onConfigChanged("sessions");
obj.setStatus("Sessions: mapping file " + file + ".");
end
