function buildMenus(obj)
%buildMenus  File / Dataset / Run / Help menus.
%   File holds the pipeline-config lifecycle (New, Open, Open recent, Save,
%   Save As, Export copy, Generate script), Create synthetic test project,
%   Open analysis app (EphysAnalysisApp on this project; onOpenAnalysisApp)
%   and Close. Dataset chooses the active dataset, the one every tab's
%   single-dataset controls work on (see selectDataset): it lists the
%   datasets ticked in the Project table, with every dataset in an "All
%   datasets" submenu. Run mirrors the Run tab's buttons. Help opens pages
%   of the GitHub wiki: the one for the tab that is shown, the home page
%   and the main guides, and at the bottom files against the repository
%   itself: Report an issue and Request a feature compose a GitHub issue
%   from this session (onReportIssue). About, last, shows the version of
%   the code (showAbout).

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
uimenu(obj.FileMenu, "Text", "Open analysis app...", ...
    "Tooltip", "Quick-look figures (PSTHs, evoked potentials, rates, tuning, probe maps) of this project's outputs.", ...
    "MenuSelectedFcn", @(~,~) obj.onOpenAnalysisApp());
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

% --- Help: pages of the GitHub wiki (helpURL), opened in the browser ------------
obj.HelpMenu = uimenu(obj.Fig, "Text", "Help");
uimenu(obj.HelpMenu, "Text", "Help for this tab", ...
    "Tooltip", "The wiki page for the tab that is shown.", ...
    "MenuSelectedFcn", @(~,~) obj.onHelp("tab"));
uimenu(obj.HelpMenu, "Text", "Documentation home", ...
    "MenuSelectedFcn", @(~,~) obj.onHelp(""));
pages = [ ...
    "Quick start",              "Quick-Start",             "on"
    "App overview",             "App-Overview",            "off"
    "Output files",             "Output-Files",            "off"
    "Troubleshooting and FAQ",  "Troubleshooting-and-FAQ", "off"
    "Scripting guide",          "Scripting-Overview",      "on"
    "Pipeline configs",         "Pipeline-Configs",        "off"
    "Developer reference",      "Architecture",            "on"];
for k = 1:height(pages)
    page = pages(k, 2);
    uimenu(obj.HelpMenu, "Text", pages(k, 1), "Separator", pages(k, 3), ...
        "MenuSelectedFcn", @(~,~) obj.onHelp(page));
end

% --- ... and the issues of the repository itself (onReportIssue) ---
uimenu(obj.HelpMenu, "Text", "Report an issue on GitHub...", "Separator", "on", ...
    "Tooltip", "Compose a bug report with the system info, the pipeline options and the logs of this session, and open it prefilled on GitHub.", ...
    "MenuSelectedFcn", @(~,~) obj.onReportIssue("bug"));
uimenu(obj.HelpMenu, "Text", "Request a feature on GitHub...", ...
    "Tooltip", "Ask for something the app does not do yet, and open the request prefilled on GitHub.", ...
    "MenuSelectedFcn", @(~,~) obj.onReportIssue("feature"));

% --- ... and which version of the code this is (showAbout, ephysVersion) ---
uimenu(obj.HelpMenu, "Text", "About EphysPreprocessingApp", "Separator", "on", ...
    "Tooltip", "The version and git commit of this code, and the MATLAB release.", ...
    "MenuSelectedFcn", @(~,~) showAbout(obj.Fig, "EphysPreprocessingApp"));
end
