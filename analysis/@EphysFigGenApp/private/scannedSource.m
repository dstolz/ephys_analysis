function K = scannedSource(S)
%scannedSource  What of a config's Source a scan reads: the one definition the app compares scans by.
%   K = scannedSource(S) keeps Mode and, in project mode, Root, OutputRoot,
%   NamePattern and Recordings (EphysProject finds and names the datasets
%   with them); in folders mode Folders (a dataset each). It leaves out
%   what a scan does not read: the ticks (Selection, Datasets: onScan lists
%   every dataset and only ticks those), the Data tab's filter (Filter:
%   which rows show), the signals' rates and filters (Downsample,
%   SignalFilter: read when a figure reads a signal), and the other mode's
%   fields (the controls keep them, disabled: syncSourceEnable). Two
%   sources with equal K list the same datasets (scanIsCurrent).
%
%   See also scanIsCurrent, onScan, gatherSourceSection.
if string(S.Mode) == "folders"
    K = struct('Mode', "folders", 'Folders', reshape(string(S.Folders), 1, []));
else
    K = struct('Mode', string(S.Mode), 'Root', string(S.Root), 'OutputRoot', string(S.OutputRoot), ...
        'NamePattern', string(S.NamePattern), 'Recordings', string(S.Recordings));
end
end
