function file = onSaveChronuxResults(obj, file)
%onSaveChronuxResults  Save the Chronux tab's result as a .mat file holding R.
%   R is what chronuxSpectrum / chronuxSpecgram returned: the spectra and
%   frequencies (and times), error bars, the trials each averages, the
%   exact Chronux params and tapers, the settings, the time base and the
%   Chronux file it came from. FILE "" asks where (uiputfile).
arguments
    obj (1,1) EphysAnalysisApp
    file (1,1) string = ""
end
R = obj.ChronuxResult;
if isempty(R); return; end
if file == ""
    [f, p] = uiputfile({'*.mat', 'MAT-file'}, "Save the Chronux result", ...
        fullfile(obj.LastExportFolder, R.dataset + "_" + R.kind + ".mat"));
    if isequal(f, 0); file = ""; return; end
    file = string(fullfile(p, f));
end
save(file, 'R', '-v7.3');
obj.log("Chronux: result saved to " + file);
obj.setStatus("Saved " + file);
end
