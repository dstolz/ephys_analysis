function buildMenus(obj)
%buildMenus  File / Dataset / Run menus.
%   File holds the pipeline-config lifecycle (New, Open, Open recent, Save,
%   Save As, Export copy, Generate script) and Close. Dataset is the app-wide
%   single-dataset picker (filled by populateDatasetMenu). Run mirrors the
%   Run tab's buttons.

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
uimenu(obj.FileMenu, "Text", "Close", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.onClose());

% --- Dataset (single-dataset picker; items filled by populateDatasetMenu) ---
obj.DatasetMenu = uimenu(obj.Fig, "Text", "Dataset");
obj.DatasetMenuItems = uimenu(obj.DatasetMenu, "Text", "(scan first)", "Enable", "off");

% --- Run ---------------------------------------------------------------------
obj.RunMenu = uimenu(obj.Fig, "Text", "Run");
uimenu(obj.RunMenu, "Text", "Validate config", "MenuSelectedFcn", @(~,~) obj.onValidate());
uimenu(obj.RunMenu, "Text", "Plan", "MenuSelectedFcn", @(~,~) obj.onPlan());
uimenu(obj.RunMenu, "Text", "Run pipeline", "Accelerator", "R", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.runPipeline());
uimenu(obj.RunMenu, "Text", "Dry run", "MenuSelectedFcn", @(~,~) obj.runPipeline(DryRun=true));
uimenu(obj.RunMenu, "Text", "Cancel", "MenuSelectedFcn", @(~,~) obj.onCancelRun());
end
