function showScanLabel(obj, S)
%showScanLabel  The Data tab's scan line for the source S: "The source changed: Scan to list its datasets." while the datasets listed are another source's.
%   showScanLabel(OBJ, S) (S the config's Source as the controls show it:
%   onConfigChanged "source", applyConfig) writes that line while the
%   runner's scan is not of S (scanIsCurrent), and the last scan's own line
%   again (what onScan wrote, kept in ScanLabel.UserData) once S is the
%   scanned source again: Run, Plan, Generate selected figure and Test
%   report refuse exactly while the line says the source changed. Nothing
%   before a scan.
%
%   See also scanIsCurrent, scannedSource, onScan.
if isempty(obj.Runner); return; end
changed = "The source changed: Scan to list its datasets.";
if ~scanIsCurrent(obj, S)
    obj.ScanLabel.Text = changed;
elseif string(obj.ScanLabel.Text) == changed && isstring(obj.ScanLabel.UserData) && isscalar(obj.ScanLabel.UserData)
    obj.ScanLabel.Text = obj.ScanLabel.UserData;   % back to the scanned source: what that scan found
end
end
