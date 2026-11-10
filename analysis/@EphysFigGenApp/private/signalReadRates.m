function [rates, notes] = signalReadRates(obj)
%signalReadRates  The rate (Hz) the figures read each signal at in the active dataset, and where it comes from, in words.
%   [RATES, NOTES] = signalReadRates(OBJ): structs with a field per signal
%   the active dataset has an extract of (none before a scan, or when it
%   cannot be read): its rate on file, or Source.Downsample's rate when
%   that is lower ("LFP of rec1 is read at 250 Hz (Downsample...; 1000 Hz
%   on file)."). The Filter dialogs draw a filter at it and refuse a
%   cutoff at or above its Nyquist frequency (onSignalFilter,
%   editPanelFilter).
%
%   See also onSignalFilter, editPanelFilter, sourceRates.
rates = struct();
notes = struct();
if isempty(obj.Runner) || obj.ActiveIdx < 1; return; end
try
    src = obj.Runner.source(obj.ActiveIdx);
catch
    return   % the rates stay unknown: the dialog says so
end
ds = sourceRates(obj.Config.Source);
for s = DatasetOutputs.SignalTypes
    if ~isfield(src.signalFs, s) || ~isfinite(src.signalFs.(s)); continue; end
    fs = src.signalFs.(s);
    note = s + " of " + src.name + " is read at " + fs + " Hz (its rate on file).";
    if isscalar(ds.(s)) && ds.(s) < fs
        fs = ds.(s);
        note = s + " of " + src.name + " is read at " + fs + " Hz (Downsample...; " + src.signalFs.(s) + " Hz on file).";
    end
    rates.(s) = fs;
    notes.(s) = note;
end
end
