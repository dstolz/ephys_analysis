function onChronuxCacheFolder(obj, folder)
%onChronuxCacheFolder  Set the local folder for Chronux files of datasets whose output folder cannot be written.
%   FOLDER "" asks with a folder dialog. Kept as the preference
%   ChronuxCacheFolder.
arguments
    obj (1,1) EphysAnalysisApp
    folder (1,1) string = ""
end
if folder == ""
    start = obj.ChronuxCacheFolder;
    if start == "" || ~isfolder(start); start = string(pwd); end
    pick = uigetdir(start, "Local folder for Chronux files");
    if isequal(pick, 0); return; end
    folder = string(pick);
end
if ~isfolder(folder)
    [ok, msg] = mkdir(folder);
    if ~ok
        obj.setStatus("Cannot create " + folder + ": " + string(msg));
        return
    end
end
obj.ChronuxCacheFolder = folder;
AppPrefs.setpref(obj.PrefGroup, 'ChronuxCacheFolder', char(folder));
obj.refreshChronuxTab();
end
