function url = helpURL(obj, page)
%helpURL  Address of a page of the GitHub wiki (EphysPreprocessingApp.WikiURL).
%   URL = helpURL(OBJ, PAGE) appends PAGE (a wiki page name such as
%   "Quick-Start", optionally with an "#anchor") to the wiki address; "" is
%   the wiki's Home page. PAGE = "tab" is the page for the selected tab.
arguments
    obj
    page (1,1) string
end
if page == "tab"
    switch obj.Tabs.SelectedTab
        case obj.TabCopy,      page = "Copy-Tab";
        case obj.TabProject,   page = "Project-Tab";
        case obj.TabTrials,    page = "Trials-Tab";
        case obj.TabProbe,     page = "Probe-Tab";
        case obj.TabArtifacts, page = "Artifacts-Tab";
        case obj.TabSorting,   page = "Sorting-Tab";
        case obj.TabSignals,   page = "Signals-Tab";
        case obj.TabSpikes,    page = "Spikes-Tab";
        case obj.TabExport,    page = "Export-Tab";
        case obj.TabFlow,      page = "Run-and-Flow-Tabs#flow-tab";
        case obj.TabRun,       page = "Run-and-Flow-Tabs#run-tab";
        case obj.TabVisualize, page = "Visualize-Tab";
        case obj.TabReview,    page = "Review-Tab";
        otherwise,             page = "App-Overview";
    end
end
url = obj.WikiURL;
if page ~= ""
    url = url + "/" + page;
end
end
