function text = figureSkipRemedy(reason)
%figureSkipRemedy  A skip reason in plain words with what to do about it ("" when it has no remedy to give).
%   TEXT = figureSkipRemedy(REASON) takes a reason of figureSkipReason or
%   figureSessionSkipReason, or the plan's "cannot read the dataset: ...",
%   and returns one sentence: what the dataset lacks and the step that
%   supplies it, the way the apps show it to someone who does not read
%   code:
%     "no LFP extract"         "No LFP signal: switch on LFP in the pipeline's Signals tab and run it."
%     "no paired trials"       "No paired trials: approve the pairing on the pipeline's Trials tab."
%     "no sorted units"        "No sorted units: run the pipeline's Sorting step on this dataset, or observe another kind of data."
%     "no line Stim"           "No line Stim in this dataset: pick a line it has (Alignment tab), or check its lines on the Data tab."
%   A reason it does not know (and "") gives "". The reasons themselves stay
%   as figureSkipReason words them: the runner's plan, the tests and the
%   generated scripts compare them.
%
%   The Export tab's plan has the sentence in its "What to do" column, and
%   the Figures tab's preview says it when the dataset cannot draw the
%   figure.
%
%   See also figureSkipReason, figureSessionSkipReason, EphysAnalysisRunner.plan.
arguments
    reason (1,1) string
end
text = "";
reason = strtrim(reason);
if reason == ""; return; end
tok = @(pattern) regexp(reason, pattern, 'tokens', 'once');

if reason == "disabled"
    text = "The figure is switched off: tick it in the Figures tab's list to draw it.";
elseif reason == "no sorted units"
    text = "No sorted units: run the pipeline's Sorting step on this dataset, or observe another kind of data.";
elseif reason == "no detected spikes"
    text = "No detected spikes: run the pipeline's Spikes step on this dataset, or observe another kind of data.";
elseif ~isempty(tok('^no (\w+) extract$'))
    t = tok('^no (\w+) extract$');
    text = "No " + t{1} + " signal: switch on " + t{1} + " in the pipeline's Signals tab and run it.";
elseif reason == "a probe figure observes units or channels, not the dataset"
    text = "A probe figure draws units or channels: set Observe to sorted units, detected spikes or a signal.";
elseif reason == "no probe map"
    text = "No probe map: give this dataset a probe (the pipeline's Probe tab, or set a default probe), then run the pipeline again.";
elseif reason == "no paired trials"
    text = "No paired trials: approve the pairing on the pipeline's Trials tab.";
elseif ~isempty(tok('^no line (.+)$'))
    t = tok('^no line (.+)$');
    text = "No line " + t{1} + " in this dataset: pick a line it has (Alignment tab), or check its lines on the Data tab.";
elseif ~isempty(tok('^no trial parameter (.+)$'))
    t = tok('^no trial parameter (.+)$');
    text = "No trial parameter " + t{1} + ": pick a parameter the trials have, or check the behavior file on the pipeline's Trials tab.";
elseif reason == "no numeric trial parameter to tune over"
    text = "No numeric trial parameter to tune over: pick one in the panel's Analysis (Parameter), or pair the behavior trials first.";
elseif startsWith(reason, "no sort event")
    text = "No event to sort the rows by: pick one in the panel's Display (Sort rows by: event), or sort by something else.";
elseif reason == "Chronux is not on the path"
    text = "Chronux is not on the MATLAB path: add the repository's toolboxes\chronux folder to the path, then try again.";
elseif ~isempty(tok('^unknown panel type (.+)$'))
    t = tok('^unknown panel type (.+)$');
    text = "The panel type " + t{1} + " is not known: pick a type in the panel's settings.";
elseif ~isempty(tok('^unknown layer source (.+)$'))
    t = tok('^unknown layer source (.+)$');
    text = "The layer's source " + t{1} + " is not known: pick a source in the Layers section.";
elseif ~isempty(tok('^(.+) panels do not draw (.+)$'))
    t = tok('^(.+) panels do not draw (.+)$');
    text = "A " + t{1} + " panel does not draw " + t{2} + ": pick a source it draws in the Layers section.";
elseif reason == "no unit or channel observed"
    text = "Nothing is observed for this figure: a layer that follows the observation needs a unit or channel figure; " + ...
        "pick one in Observe, or bind the layer to fixed channels.";
elseif startsWith(reason, "AUX has no recording channel")
    text = "AUX has no recording channel to follow: bind the layer to fixed channels (Layers section).";
elseif startsWith(reason, "events are drawn as a train only on")
    text = "Events as a train need a raster, PSTH or heat map panel: draw them as marks instead (Layers section).";
elseif reason == "not a session figure"
    text = "This figure is drawn per dataset: tick Across datasets in its Sessions section to draw it across datasets.";
elseif ~isempty(tok('^(.+) panels are not merged across sessions$'))
    t = tok('^(.+) panels are not merged across sessions$');
    text = "A " + t{1} + " panel cannot be merged across datasets: remove it, or untick Across datasets.";
elseif reason == "an auROC baseline is not merged across sessions"
    text = "An auROC baseline cannot be merged across datasets: pick another baseline, or untick Across datasets.";
elseif reason == "no mapping file"
    text = "Units are matched by a mapping file, but none is chosen: pick it in the Sessions section, or match the units another way.";
elseif startsWith(reason, "mapping file not found")
    text = "The mapping file was not found: pick it again in the Sessions section.";
elseif startsWith(reason, "fewer than ")
    text = "Too few datasets can draw this figure (the reasons are listed in brackets): fix those, or lower Min. sessions in its Sessions section.";
elseif startsWith(reason, "cannot read the dataset")
    text = "The dataset could not be read: check its output files with the pipeline app, then scan again.";
end
end
