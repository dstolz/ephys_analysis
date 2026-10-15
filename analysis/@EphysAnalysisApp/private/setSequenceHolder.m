function setSequenceHolder(holder, data)
%setSequenceHolder  Keep an event sequence in its summary label and show it.
%   setSequenceHolder(HOLDER, DATA) stores DATA, struct('sequence', STEPS,
%   'alignStep', A) -- an event reference's or a stop's steps
%   (buildAlignControls' "Sequence" rows, the figure editor's event and
%   sort rows) -- in the label HOLDER's UserData and writes its summary as
%   the label's text and tooltip: "none", or the steps after the line,
%   e.g. "then Trough onset". editSequence edits DATA; gatherAlignControls
%   and gatherFigureEditor read it back.
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
holder.UserData = data;
holder.Text = txt;
holder.Tooltip = txt;
end
