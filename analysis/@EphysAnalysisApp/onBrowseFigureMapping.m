function onBrowseFigureMapping(obj, file)
%onBrowseFigureMapping  Pick the selected session figure's unit-mapping file (a .csv).
%   The Browse... button of the Figures tab's Sessions section: a file
%   dialog starting in the
%   current file's folder (else the config's). FILE skips the dialog
%   (scripts, tests). The file goes into the Mapping file box and the
%   config (onConfigChanged "figure"); it is read when the observations
%   are matched (figureSessionObservations).
arguments
    obj (1,1) EphysAnalysisApp
    file (1,1) string = ""
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("Figures: add or select a figure first.");
    return
end
if file == ""
    start = obj.Config.Figures(k).sessions.mappingFile;
    if start ~= "" && ~isfolder(fileparts(start)); start = ""; end
    if start == "" && obj.Config.File ~= ""; start = string(fileparts(obj.Config.File)) + filesep; end
    if start == ""; start = string(pwd) + filesep; end
    [f, p] = uigetfile({'*.csv', 'Unit mapping (*.csv)'; '*.*', 'All files'}, 'Unit mapping file', char(start));
    if isequal(f, 0); return; end
    file = string(fullfile(p, f));
end
obj.FigureEditor.sesMappingFile.Value = char(file);
obj.onConfigChanged("figure");
obj.setStatus("Figures: mapping file " + file + ".");
end
