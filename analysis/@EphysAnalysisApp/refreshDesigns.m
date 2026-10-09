function refreshDesigns(obj)
%refreshDesigns  The Design menu and the preview's Design list, from PlotDesign.list.
%   The chosen design is ticked in the menu and shown in the list (its
%   description as the list's tooltip). Called when the app is built and,
%   through PlotDesign.listen, whenever a design is chosen, saved, imported
%   or deleted anywhere (a plot's right-click menu too).
arguments
    obj (1,1) EphysAnalysisApp
end
if isempty(obj.DesignMenu) || ~isvalid(obj.DesignMenu); return; end
T = PlotDesign.list();
cur = PlotDesign.currentName();
k = find(strcmpi(T.Name, cur), 1);
if isempty(k); k = 1; end
labels = T.Name;
mine = T.Source == "mine";
labels(mine) = labels(mine) + "  (mine)";
set(obj.DesignDropDown, "Items", labels, "ItemsData", T.Name, "Value", T.Name(k), ...
    "Tooltip", T.Name(k) + ": " + T.Description(k) + newline + "Choosing a design redraws every plot on screen; " + ...
    "runs draw their figures in it too.");

m = obj.DesignMenu;
delete(m.Children);
for i = 1:height(T)
    name = T.Name(i);
    uimenu(m, "Text", labels(i), "Checked", matlab.lang.OnOffSwitchState(i == k), ...
        "Separator", matlab.lang.OnOffSwitchState(i > 1 && T.Source(i) ~= T.Source(i - 1)), ...
        "Tooltip", T.Description(i), "MenuSelectedFcn", @(~,~) obj.onDesignChosen(name));
end
uimenu(m, "Text", "Save the preview's look as a design...", "Separator", "on", ...
    "Tooltip", "Every property of every component of the preview, its ground and its group colors, as a design of yours.", ...
    "MenuSelectedFcn", @(~,~) obj.onSaveDesign());
uimenu(m, "Text", "Import a design file...", "Tooltip", "Copy a design (.json) into your designs folder, e.g. one a colleague saved.", ...
    "MenuSelectedFcn", @(~,~) obj.onImportDesign());
del = uimenu(m, "Text", "Delete one of my designs", "Enable", matlab.lang.OnOffSwitchState(any(mine)));
for i = find(mine).'
    name = T.Name(i);
    uimenu(del, "Text", name, "MenuSelectedFcn", @(~,~) obj.onDeleteDesign(name));
end
uimenu(m, "Text", "Open my designs folder", "Separator", "on", "Tooltip", PlotDesign.folder(), ...
    "MenuSelectedFcn", @(~,~) obj.onDesignsFolder("open"));
uimenu(m, "Text", "Keep my designs in...", "Tooltip", "Another folder for your designs, such as one the lab shares.", ...
    "MenuSelectedFcn", @(~,~) obj.onDesignsFolder("choose"));
end
