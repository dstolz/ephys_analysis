function [vars, names, widths] = synthColumns(~, kind)
%synthColumns  The Synthetic tab's units / LFP table columns, in display order.
%   [VARS, NAMES, WIDTHS] = app.synthColumns(KIND) with KIND "unit" or
%   "lfp": the SyntheticDesign column behind each table column, its header
%   and its width. buildSyntheticTab, gatherSynthDesign and applySynthDesign
%   all go through this, so the order is set here only.
if kind == "unit"
    vars   = ["Name" "Event" "Edge" "Shape" "Gain" "LatencyMs" "DurationMs" "JitterMs" ...
        "BaselineHz" "Channel" "AmplitudeUV" "WidthMs" "Parameter" "Tuning"];
    names  = {'Name', 'Event', 'Edge', 'Shape', 'Gain', 'Latency (ms)', 'Duration (ms)', 'Jitter (ms)', ...
        'Baseline (Hz)', 'Channel', 'Amplitude (uV)', 'Width (ms)', 'Parameter', 'Tuning'};
    widths = {60, 90, 62, 95, 50, 72, 82, 66, 82, 58, 90, 70, 90, 90};
else
    vars   = ["Name" "Kind" "Event" "Edge" "FrequencyHz" "AmplitudeUV" "LatencyMs" "DurationMs" ...
        "RiseMs" "PhaseLocked" "Profile" "JitterMs" "Parameter" "Tuning"];
    names  = {'Name', 'Kind', 'Event', 'Edge', 'Freq (Hz)', 'Amplitude (uV)', 'Latency (ms)', 'Duration (ms)', ...
        'Rise (ms)', 'Locked', 'Profile', 'Jitter (ms)', 'Parameter', 'Tuning'};
    widths = {70, 90, 90, 62, 64, 90, 72, 82, 62, 52, 90, 66, 90, 90};
end
end
