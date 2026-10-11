function [vars, names, widths] = synthColumns(~, kind)
%synthColumns  The Synthetic tab's units / evoked-potential table columns, in display order.
%   [VARS, NAMES, WIDTHS] = app.synthColumns(KIND) with KIND "unit" or
%   "lfp": the SyntheticDesign column behind each table column, its header
%   and its width. buildSyntheticTab, gatherSynthDesign, applySynthDesign
%   and syncSynthControls all go through this, so the order is set here only.
if kind == "unit"
    vars   = ["Name" "Event" "Edge" "Gain" "LatencyMs" "DurationMs" "BaselineHz" "Channel" ...
        "AmplitudeUV" "Parameter"];
    names  = {'Name', 'Event', 'Edge', 'Gain', 'Latency (ms)', 'Duration (ms)', 'Baseline (Hz)', 'Channel', ...
        'Amplitude (uV)', 'Parameter'};
    widths = {60, 90, 62, 50, 72, 82, 82, 58, 90, 90};
else
    vars   = ["Name" "Event" "Edge" "AmplitudeUV" "LatencyMs" "DurationMs" "Channel" "Parameter"];
    names  = {'Name', 'Event', 'Edge', 'Amplitude (uV)', 'Latency (ms)', 'Duration (ms)', 'Channel', 'Parameter'};
    widths = {70, 90, 62, 90, 72, 82, 58, 90};
end
end
