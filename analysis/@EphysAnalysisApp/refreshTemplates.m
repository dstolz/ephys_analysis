function refreshTemplates(obj, pick)
%refreshTemplates  The Figures tab's Template list, from your templates folder (FigureTemplate.list).
%   refreshTemplates(OBJ) lists your figure templates by name, keeping the
%   one picked while it is there (else the first), and gives the list the
%   picked one's description, shape (FigureTemplate.summary), when it was
%   saved and what reading it reported (a "(!)" after its name), as its
%   tooltip. Apply..., Update, Remove and Export... are off with no
%   template (Save as... and Update say so when no figure is selected).
%   refreshTemplates(OBJ, PICK) picks the template PICK (a name).
%   The list is read again each time it opens (its DropDownOpeningFcn), so
%   a template saved, imported or deleted elsewhere (another app, a script,
%   the folder) shows up.
arguments
    obj (1,1) EphysAnalysisApp
    pick (1,1) string = string(missing)
end
dd = obj.FigureTemplateDropDown;
if isempty(dd) || ~isvalid(dd); return; end
try
    T = FigureTemplate.list();
catch ME   % the folder cannot be read: say so, list none
    T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', ["Name" "Description" "Summary" "Saved" "File" "Problem"]);
    obj.setStatus("Figure templates: " + string(ME.message));
end
if ismissing(pick); pick = string(dd.Value); end
if isempty(T)
    if ~isequal(string(dd.ItemsData), "")
        set(dd, "Items", "(no templates)", "ItemsData", "");
    end
    dd.Value = "";
    dd.Tooltip = "No figure templates yet: Save as... keeps the figure shown as one, Import... adds a template file. " + ...
        "Your templates folder: " + FigureTemplate.folder() + ".";
else
    labels = T.Name;
    bad = T.Problem ~= "";
    labels(bad) = labels(bad) + "  (!)";
    if ~isequal(string(dd.ItemsData), reshape(T.Name, 1, [])) || ~isequal(string(dd.Items), reshape(labels, 1, []))
        set(dd, "Items", labels, "ItemsData", T.Name);
    end
    k = find(strcmpi(T.Name, pick), 1);
    if isempty(k); k = 1; end
    dd.Value = T.Name(k);
    tip = T.Name(k);
    if T.Description(k) ~= ""; tip = tip + ": " + T.Description(k); end
    if T.Summary(k) ~= ""; tip = tip + newline + T.Summary(k); end
    if T.Saved(k) ~= ""; tip = tip + newline + "Saved " + T.Saved(k) + "."; end
    if T.Problem(k) ~= ""; tip = tip + newline + "Reading it: " + T.Problem(k) + "."; end
    dd.Tooltip = tip + newline + "Your templates folder: " + FigureTemplate.folder() + ".";
end
set([obj.FigureTemplateApplyButton obj.FigureTemplateUpdateButton obj.FigureTemplateRemoveButton obj.FigureTemplateExportButton], ...
    "Enable", matlab.lang.OnOffSwitchState(~isempty(T)));
end
