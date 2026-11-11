function T = labelVariableValues(obj)
%labelVariableValues  The label variables (figureLabelVariables) with their values on the figure previewed: its selected panel's.
%   T = app.labelVariableValues() is figureLabelVariables' table with its
%   Value column for the Figures tab's selected figure (Config.figureFor)
%   as its preview last computed it (FigurePreviewResult, when it is that
%   figure's), at its selected panel (SelectedPanel; 0 or none: the
%   figure's own alignment and trials). Its rows end with the dataset
%   variables in use on the scanned datasets (datasetVariableSets: Topic
%   "Dataset variables"), each valued from the previewed figure's dataset
%   (blank when that dataset has none). With no figure, or one that cannot
%   be resolved, the Values are blank; without a preview the
%   observation's, the dataset's, the epochs' and the dataset variables'
%   are "<Name>". The "{x}" buttons' menus (labelVariableButton) and the
%   list (onLabelVariables) show them.
%
%   See also figureLabelVariables, onLabelVariables, datasetVariableSets.
sets = obj.datasetVariableSets();
T = figureLabelVariables(Variables=sets);
T.Value = strings(height(T), 1);
k = obj.SelectedFigure;
if isempty(obj.Config) || k < 1 || k > numel(obj.Config.Figures); return; end
try
    spec = obj.Config.figureFor(k);
catch
    return
end
F = obj.FigurePreviewResult;
if ~(isstruct(F) && isscalar(F) && isfield(F, 'id') && string(F.id) == string(spec.id))
    F = [];
end
p = obj.SelectedPanel;
if p < 0 || p > numel(spec.panels); p = 0; end
try
    T = figureLabelVariables(spec, F, Panel=p, Variables=sets);
catch
end
end
