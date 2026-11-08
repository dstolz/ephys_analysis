function onVizSaveSVG(obj, file)
%onVizSaveSVG  Save the Visualize plot's view as an SVG of vectors.
%   obj.onVizSaveSVG() asks where (a save dialog, starting in the folder
%   used last, else the shown dataset's output folder, named
%   "<Name>_<start>s.svg") and writes the view with
%   EphysTraceViewer.exportSVG: the traces, one path per lane; each unit's
%   or channel's spikes, one path each, on top of them; the event lines and
%   TTL rows; the scale bar and the axes. The shaded artifact periods and
%   the overview strip are left out. obj.onVizSaveSVG(FILE) writes FILE
%   without asking.
%
%   See also EphysTraceViewer.exportSVG, buildVisualizeTab.

v = obj.Viewer;
d = obj.currentVizDataset();
if isempty(v) || ~isvalid(v) || isempty(d) || isempty(obj.VizData)
    obj.setStatus("Save view as SVG: no dataset is shown on the Visualize tab.");
    return
end
if nargin < 2
    folder = obj.VizSVGFolder;
    if folder == "" || ~isfolder(folder); folder = d.outputFolder(); end
    start = fullfile(folder, sprintf("%s_%gs.svg", d.Name, round(v.TStart, 3)));
    [f, p] = uiputfile({'*.svg', 'SVG image (*.svg)'}, "Save the view as SVG", start);
    figure(obj.Fig);
    if isequal(f, 0); return; end
    file = fullfile(p, f);
end
file = string(file);
try
    file = v.exportSVG(file);
catch ME
    obj.reportFailure("Visualize", "save the view as SVG", string(d.Name), ME, ...
        "check that the folder can be written to, then try again");
    obj.setStatus("Save view as SVG failed: " + string(ME.message));
    return
end
obj.VizSVGFolder = string(fileparts(file));
obj.setStatus("View saved to " + file);
end
