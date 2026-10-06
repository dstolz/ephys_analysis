function onFindSorters(obj)
%onFindSorters  List the SpikeInterface sorters installed in the Python env.
%   Runs EphysDataset.spikeInterfaceSorters with the Sorting tab's Python
%   exe (else defaultPythonExe) and Conda env, keeps what it finds in
%   SISorters / SIVersion and in the preference SISorters (so the list is
%   there when the app next opens), and refills the Sorter drop-down. A
%   Python without spikeinterface says so in an alert.
%
%   See also refreshSorterItems, showSorterControls.
py = strtrim(string(obj.PythonExeField.Value));
if py == ""; py = string(obj.defaultPythonExe()); end
conda = strtrim(string(obj.CondaEnvField.Value));
if py == ""
    uialert(obj.Fig, "Set the Python exe of the env SpikeInterface is installed in first.", ...
        "Find SpikeInterface sorters");
    return
end
dlg = uiprogressdlg(obj.Fig, "Title", "Find SpikeInterface sorters", "Indeterminate", "on", ...
    "Message", "Asking " + py + " which SpikeInterface sorters it has (this imports SpikeInterface)...");
cleanup = onCleanup(@() delete(dlg));
try
    [sorters, info] = EphysDataset.spikeInterfaceSorters(PythonExe=py, CondaEnv=conda);
catch ME
    delete(dlg);
    obj.log("[sorting] finding SpikeInterface sorters failed: %s", ME.message);
    uialert(obj.Fig, string(ME.message), "Find SpikeInterface sorters");
    return
end
obj.SISorters = sorters;
obj.SIVersion = info.spikeinterface;
try
    AppPrefs.setpref(obj.PrefGroup, 'SISorters', struct('python', py, ...
        'spikeinterface', info.spikeinterface, 'when', info.when, 'sorters', sorters));
catch ME
    obj.log("[sorting] could not remember the SpikeInterface sorters: %s", ME.message);
end
obj.refreshSorterItems();
obj.showSorterControls();
names = [sorters.name];
names = names(EphysDataset.isSpikeInterfaceSorter(names));
if isempty(names)
    msg = "SpikeInterface " + info.spikeinterface + " in " + py + " has no sorter installed but Kilosort4.";
else
    msg = sprintf("SpikeInterface %s in %s: %d sorter(s), %s.", info.spikeinterface, py, numel(names), ...
        strjoin(names, ", "));
end
obj.log("[sorting] %s", msg);
obj.setStatus(msg);
end
