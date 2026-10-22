function buildMenus(obj)
%buildMenus  File, Edit, Design and Help menus.
%   File: the analysis-config lifecycle (New, Open, Open recent, Save, Save
%   As), Generate script (compact | standalone), Open pipeline app and
%   Close. Edit: Undo (Ctrl+Z) and Redo (Ctrl+Y) of the figure editor's
%   edits (onUndoRedo), named after the edit and grayed with none, or off
%   the Figures tab (refreshEditMenu). Design: the plot designs and what to do with them (filled by
%   refreshDesigns). Help: the wiki page of the tab shown, the Figures
%   tab's keys (onFigureKeys), the
%   documentation home and the analysis quick start (helpURL), Report an
%   issue and Request a feature, which file against the repository itself
%   (onReportIssue), and About (showAbout): the version of the code.

obj.FileMenu = uimenu(obj.Fig, "Text", "File");
uimenu(obj.FileMenu, "Text", "New config", "Accelerator", "N", "MenuSelectedFcn", @(~,~) obj.onNewConfig());
uimenu(obj.FileMenu, "Text", "Open config...", "Accelerator", "O", "MenuSelectedFcn", @(~,~) obj.onOpenConfig());
obj.RecentMenu = uimenu(obj.FileMenu, "Text", "Open recent");
uimenu(obj.RecentMenu, "Text", "(none)", "Enable", "off");
uimenu(obj.FileMenu, "Text", "Save config", "Accelerator", "S", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.onSaveConfig());
uimenu(obj.FileMenu, "Text", "Save config as...", "MenuSelectedFcn", @(~,~) obj.onSaveConfigAs());
gen = uimenu(obj.FileMenu, "Text", "Generate script", "Separator", "on");
uimenu(gen, "Text", "Compact (loads the saved config)...", "MenuSelectedFcn", @(~,~) obj.onGenerateScript("compact"));
uimenu(gen, "Text", "Standalone (every setting written out)...", "MenuSelectedFcn", @(~,~) obj.onGenerateScript("standalone"));
uimenu(obj.FileMenu, "Text", "Open pipeline app", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.onOpenPipelineApp());
uimenu(obj.FileMenu, "Text", "Close", "Separator", "on", "MenuSelectedFcn", @(~,~) obj.onClose());

obj.EditMenu = uimenu(obj.Fig, "Text", "Edit");
tip = "The figure editor's edits (Figures tab): its layout, panels, layers, options and the figure list.";
obj.UndoMenu = uimenu(obj.EditMenu, "Text", "Undo", "Accelerator", "Z", "Enable", "off", "Tooltip", tip, ...
    "MenuSelectedFcn", @(~,~) obj.onUndoRedo("undo"));
obj.RedoMenu = uimenu(obj.EditMenu, "Text", "Redo", "Accelerator", "Y", "Enable", "off", "Tooltip", tip + " Also Ctrl+Shift+Z.", ...
    "MenuSelectedFcn", @(~,~) obj.onUndoRedo("redo"));
obj.ApplyMenu = uimenu(obj.EditMenu, "Text", "Apply last change to figures...    Ctrl+Shift+A", "Separator", "on", "Enable", "off", ...
    "Tooltip", "Give the last edit of the figure editor to other figures or panels, picked in a list (or hold Ctrl while you edit).", ...
    "MenuSelectedFcn", @(~,~) obj.onApplyToFigures());

obj.DesignMenu = uimenu(obj.Fig, "Text", "Design");

obj.HelpMenu = uimenu(obj.Fig, "Text", "Help");
uimenu(obj.HelpMenu, "Text", "Help for this tab", "Tooltip", "The wiki page for the tab that is shown.", ...
    "MenuSelectedFcn", @(~,~) obj.onHelp("tab"));
uimenu(obj.HelpMenu, "Text", "Figures tab keys", "Tooltip", "Every key of the Figures tab, to work it with the keyboard alone.", ...
    "MenuSelectedFcn", @(~,~) obj.onFigureKeys());
uimenu(obj.HelpMenu, "Text", "Documentation home", "MenuSelectedFcn", @(~,~) obj.onHelp(""));
uimenu(obj.HelpMenu, "Text", "Analysis quick start", "Separator", "on", ...
    "MenuSelectedFcn", @(~,~) obj.onHelp("Analysis-App#quick-start"));
uimenu(obj.HelpMenu, "Text", "Analysis configs", "MenuSelectedFcn", @(~,~) obj.onHelp("Analysis-Configs"));

% --- ... and the issues of the repository itself (onReportIssue) ---
uimenu(obj.HelpMenu, "Text", "Report an issue on GitHub...", "Separator", "on", ...
    "Tooltip", "Compose a bug report with the system info, the analysis config and the log of this session, and open it prefilled on GitHub.", ...
    "MenuSelectedFcn", @(~,~) obj.onReportIssue("bug"));
uimenu(obj.HelpMenu, "Text", "Request a feature on GitHub...", ...
    "Tooltip", "Ask for something the app does not do yet, and open the request prefilled on GitHub.", ...
    "MenuSelectedFcn", @(~,~) obj.onReportIssue("feature"));

uimenu(obj.HelpMenu, "Text", "About EphysAnalysisApp", "Separator", "on", ...
    "Tooltip", "The version and git commit of this code, and the MATLAB release.", ...
    "MenuSelectedFcn", @(~,~) showAbout(obj.Fig, "EphysAnalysisApp"));
end
