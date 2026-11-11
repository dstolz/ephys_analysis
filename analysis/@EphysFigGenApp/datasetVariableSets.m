function sets = datasetVariableSets(obj, idx)
%datasetVariableSets  The scanned datasets' variables (DatasetVariables sets), a cell with one per dataset in the Runner.
%   SETS = app.datasetVariableSets() holds, for each dataset of the Data
%   tab (Runner.Outputs, in its order), its loaded source's variables
%   (src.variableInfo), else its manifest's (outputVariables: read once
%   per dataset). SETS = app.datasetVariableSets(IDX) holds those of the
%   datasets IDX (indices into Runner.Outputs; others are left out). []
%   before a scan: not known (EphysAnalysisConfig.validate then says a
%   name may be a dataset variable's). The variable dialog
%   (onEditVariables) offers the variables in use across them, the "{x}"
%   buttons' menus and the label variables' list (labelVariableValues)
%   list them, the config check (onValidate, onRunExport) takes them as
%   label variables, and a preview drawn with other values is out of date
%   (figureViewKey).
%
%   See also DatasetVariables, outputVariables, onEditVariables, labelVariableValues.
sets = [];
r = obj.Runner;
if isempty(r) || isempty(r.Keys); return; end
if nargin < 2; idx = 1:numel(r.Outputs); end
idx = reshape(idx(idx >= 1 & idx <= numel(r.Outputs)), 1, []);
sets = cell(1, numel(idx));
for j = 1:numel(idx)
    k = idx(j);
    key = char(r.Keys(k));
    if isKey(r.Sources, key) && isfield(r.Sources(key), 'variableInfo')
        sets{j} = DatasetVariables.fromInfo(r.Sources(key).variableInfo);
    else
        sets{j} = outputVariables(r.Outputs(k));
    end
end
end
