function onOpenTool(obj, tool)
%onOpenTool  Open the Tools panel's datasets (toolTargets) in another program.
%   TOOL is
%     "manifest"  each dataset's manifest in a ManifestViewerApp (onViewManifest)
%     "analysis"  one EphysAnalysisApp on them all (onOpenAnalysisApp)
%     "phy"       phy's template-gui on each that has sorted output (onLaunchPhy)
%     "folder"    each output folder in the file browser (onOpenOutputFolder)
%   Opening more than four windows at once is asked about first.
%
%   See also EphysPreprocessingApp.toolTargets, EphysPreprocessingApp.syncToolsPanel.
arguments
    obj (1,1) EphysPreprocessingApp
    tool (1,1) string {mustBeMember(tool, ["manifest" "analysis" "phy" "folder"])}
end
idx = obj.toolTargets();
if isempty(idx)
    uialert(obj.Fig, "Scan a project first.", "Tools");
    return
end
if tool == "phy"
    has = false(size(idx));
    for k = 1:numel(idx)
        has(k) = obj.Project.Datasets(idx(k)).hasPhyOutput();
    end
    idx = idx(has);
    if isempty(idx)
        uialert(obj.Fig, "None of these datasets has sorted output (a params.py) for phy.", "Tools");
        return
    end
end

windows = struct('manifest', "manifest viewers", 'phy', "phy windows", 'folder', "folder windows");
if tool ~= "analysis" && numel(idx) > 4
    answer = uiconfirm(obj.Fig, sprintf("Open %d %s, one per dataset?", numel(idx), windows.(tool)), ...
        "Tools", "Options", ["Open all", "Cancel"], "DefaultOption", 2, "CancelOption", 2);
    if answer ~= "Open all"; return; end
end

switch tool
    case "manifest"; obj.onViewManifest(idx);
    case "analysis"; obj.onOpenAnalysisApp(idx);
    case "phy";      obj.onLaunchPhy(idx);
    case "folder";   obj.onOpenOutputFolder(idx);
end
end
