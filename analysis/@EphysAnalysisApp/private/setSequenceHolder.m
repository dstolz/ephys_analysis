function setSequenceHolder(holder, data)
%setSequenceHolder  Keep an event sequence in its summary label and show it.
%   setSequenceHolder(HOLDER, DATA) stores DATA in the label HOLDER's
%   UserData and writes its summary as the label's text and tooltip:
%     struct('sequence', STEPS, 'alignStep', A)   an event reference's or
%         a stop's steps (buildAlignControls' "Sequence" rows): "none", or
%         the steps after the panel's line, e.g. "then Trough onset"
%     a 1 x n EventRef struct array   a plot's mark sequences (the plot
%         editor's "Mark sequences" row): "none", or each one's
%         eventRefLabel, "; " between
%   editSequence edits DATA; gatherAlignControls / gatherPlotEditor read it
%   back.
if isfield(data, 'alignStep') && ~isfield(data, 'line')
    if isempty(data.sequence)
        txt = "none";
    else
        r = EphysAnalysisConfig.defaults("EventRef");
        r.line = char(1);   % a placeholder for the panel's line, cut off below
        r.sequence = data.sequence;
        r.alignStep = data.alignStep;
        lbl = eventRefLabel(r);
        txt = replace(extractAfter(lbl, strlength(r.line + " " + r.edge + " ")), r.line + " " + r.edge, "the event");
    end
elseif isempty(data)
    txt = "none";
else
    txt = strjoin(arrayfun(@eventRefLabel, data), "; ");
end
holder.UserData = data;
holder.Text = txt;
holder.Tooltip = txt;
end
