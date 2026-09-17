function buildMenus(obj)
%buildMenus  File / Dataset / Run menus.
%   File holds the pipeline-config lifecycle (New, Open, Open recent, Save,
%   Save As, Export copy, Generate script), Create synthetic test project
%   and Close. Dataset chooses the active dataset, the one every tab's
%   single-dataset controls work on (see selectDataset): it lists the
%   datasets ticked in the Project table, with every dataset in an "All
%   datasets" submenu. Run mirrors the Run tab's buttons.

% --- File ------------------------------------------------------------------
obj.FileMenu = uimenu(obj.Fig, "Text", "File");
uimenu(obj.FileMenu, "Text", "New config", "Accelerator", "N", ...
    "MenuSelectedFcn", @(~,~) obj.onNewConfig());
uimenu(obj.FileMenu, "Text", "Open config...", "Accelerator", "O", ...
    "MenuSelectedFcn", @(~,~) obj.onOpenConfig());
obj.RecentMenu = uimenu(obj.FileMenu, "Text", "Open recent");
uimenu(obj.RecentMenu, "Text", "(none)", "Enable", "off");
uimenu(obj.FileMenu, "Text", "Save config", "Accelerator", "S", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.onSaveConfig());
uimenu(obj.FileMenu, "Text", "Save config as...", ...
    "MenuSelectedFcn", @(~,~) obj.onSaveConfigAs());
uimenu(obj.FileMenu, "Text", "Export copy of config...", ...
    "MenuSelectedFcn", @(~,~) obj.onExportConfigCopy());
gen = uimenu(obj.FileMenu, "Text", "Generate script", "Separator", "on");
uimenu(gen, "Text", "Compact (loads the saved config)...", ...
    "MenuSelectedFcn", @(~,~) obj.onGenerateScript("compact"));
uimenu(gen, "Text", "Standalone (every parameter written out)...", ...
    "MenuSelectedFcn", @(~,~) obj.onGenerateScript("standalone"));
uimenu(obj.FileMenu, "Text", "Create synthetic test project...", "Separator", "on", ...
    "Tooltip", "Write synthetic recordings with Epsych2 sessions and sorted output, then open and scan them.", ...
    "MenuSelectedFcn", @(~,~) obj.onCreateSyntheticProject());
uimenu(obj.FileMenu, "Text", "Close", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.onClose());

% --- Dataset: the active dataset. The ticked datasets on top (refreshDatasetMenu),
% every dataset under "All datasets" (populateDatasetPickers) ---
obj.DatasetMenu = uimenu(obj.Fig, "Text", "Dataset", ...
    "Tooltip", "The active dataset: what the single-dataset controls on every tab work on. Also chosen by clicking a Project-table row or in any tab's Dataset box.");
obj.DatasetAllMenu = uimenu(obj.DatasetMenu, "Text", "All datasets", "Separator", "on", "Enable", "off");
obj.refreshDatasetMenu();

% --- Run ---------------------------------------------------------------------
obj.RunMenu = uimenu(obj.Fig, "Text", "Run");
uimenu(obj.RunMenu, "Text", "Validate config", "MenuSelectedFcn", @(~,~) obj.onValidate());
uimenu(obj.RunMenu, "Text", "Plan", "MenuSelectedFcn", @(~,~) obj.onPlan());
uimenu(obj.RunMenu, "Text", "Run pipeline", "Accelerator", "R", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.runPipeline());
uimenu(obj.RunMenu, "Text", "Dry run", "MenuSelectedFcn", @(~,~) obj.runPipeline(DryRun=true));
uimenu(obj.RunMenu, "Text", "Cancel", "MenuSelectedFcn", @(~,~) obj.onCancelRun());
end
