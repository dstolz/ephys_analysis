function url = helpURL(obj, page)
%helpURL  Address of a wiki page (EphysAnalysisApp.WikiURL); "tab" = the shown tab's section.
arguments
    obj
    page (1,1) string
end
if page == "tab"
    switch obj.Tabs.SelectedTab
        case obj.TabData,   page = "Analysis-App#data-tab";
        case obj.TabAlign,  page = "Analysis-App#alignment-tab";
        case obj.TabPlots,  page = "Analysis-App#plots-tab";
        case obj.TabExport, page = "Analysis-App#export-tab";
        otherwise,          page = "Analysis-App#log-tab";
    end
end
url = obj.WikiURL;
if page ~= ""; url = url + "/" + page; end
end
