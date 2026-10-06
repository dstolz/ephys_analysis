function onReviewQCReport(obj)
%onReviewQCReport  Write the loaded sort's unit-quality page and open it.
%   writeUnitQualityReport of the units the Review tab shows (with their
%   quality metrics, EphysDataset.unitQuality) and the good-unit criteria
%   above the table, into <results folder>/quality_report.html; it then
%   opens in the system browser. Without metrics (they could not be
%   computed) the summary says why. Writing it reads the good units' spikes
%   for their mean waveforms, under a progress dialog.
R = obj.ReviewData;
if isempty(R) || ~isfield(R, 'units')
    uialert(obj.Fig, "Load a Kilosort4 results folder first.", "QC report");
    return
end
if ~isfield(R.units, 'presenceRatio')
    uialert(obj.Fig, "The quality metrics of this sort could not be computed: " + R.qualityNote, "QC report");
    return
end
[S, err] = obj.gatherSortingSection();
if err ~= ""
    uialert(obj.Fig, err, "QC report");
    return
end
dlg = uiprogressdlg(obj.Fig, "Title", "QC report", "Indeterminate", "on", ...
    "Message", "Reading the good units' spikes for their mean waveforms...");
drawnow;
try
    file = writeUnitQualityReport(R.units, "", Criteria=S.Quality);
catch ME
    close(dlg);
    uialert(obj.Fig, "Could not write the QC report:" + newline + string(ME.message), "QC report");
    return
end
close(dlg);
obj.setStatus("Wrote " + file, "");
try
    web(char(file), '-browser');
catch
end
end
