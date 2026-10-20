function onReviewQCReport(obj)
%onReviewQCReport  Write the loaded sort's unit-quality page and open it.
%   writeUnitQualityReport of the units the Review tab shows (with their
%   quality metrics, EphysDataset.unitQuality) and the good-unit criteria
%   above the table, into <results folder>/quality_report.html; it then
%   opens in the system browser. Without metrics (they could not be
%   computed) the summary says why. Writing it reads the good units' spikes
%   for their mean waveforms, under a progress dialog that counts the units
%   and says the time left.
R = obj.ReviewData;
if isempty(R) || ~isfield(R, 'units')
    uialert(obj.Fig, "Load a sort first.", "QC report");
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
dlg = uiprogressdlg(obj.Fig, "Title", "QC report", "Value", 0, ...
    "Message", "Reading the good units' spikes for their mean waveforms...");
drawnow;
clock = ProgressClock();
try
    file = writeUnitQualityReport(R.units, "", Criteria=S.Quality, ...
        ProgressFcn=@(done, total, msg) progress(dlg, clock, done / max(total, 1), msg));
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


function progress(dlg, clock, frac, msg)
if ~isvalid(dlg); return; end
dlg.Value = min(max(frac, 0), 1);
dlg.Message = char(clock.message(msg, frac));
drawnow limitrate;
end
