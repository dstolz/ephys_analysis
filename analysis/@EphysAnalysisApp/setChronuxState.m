function setChronuxState(obj, state, opts)
%setChronuxState  Show where the Chronux tab's plot is: the badge under it, the buttons, the pointer.
%   STATE:
%     idle       nothing computed (no file, or Compute not pressed)
%     creating   the Chronux file is being written (it cannot be stopped)
%     computing  the analysis is running: Cancel stops it at its next channel
%     drawn      the plot is the analysis as set now
%     stale      a setting changed since it was computed: press Compute
%     failed     creating, computing or drawing failed (the line beside it says why)
%     canceled   Cancel stopped the analysis
%   While creating or computing the dataset cannot change, Compute and
%   Create are off and the pointer is a watch. Message= sets the status line.
arguments
    obj (1,1) EphysAnalysisApp
    state (1,1) string {mustBeMember(state, ["idle" "creating" "computing" "drawn" "stale" "failed" "canceled"])}
    opts.Message (1,1) string = ""
end
obj.ChronuxState = state;
B = obj.ChronuxBadge;
if isempty(fieldnames(B)) || ~isvalid(B.Grid); return; end
amber = {[1.00 0.93 0.75], [0.55 0.33 0.00]};
green = {[0.85 0.94 0.87], [0.10 0.40 0.20]};
gray  = {[0.92 0.92 0.92], [0.35 0.35 0.35]};
red   = {[0.98 0.86 0.84], [0.60 0.15 0.10]};
icon = state;
switch state
    case "idle";      [word, c, tip] = deal("Not computed", gray, "Nothing is computed yet: press Compute.");
    case "creating";  [word, c, tip] = deal("Creating", amber, "Writing the dataset's Chronux file."); icon = "computing";
    case "computing"; [word, c, tip] = deal("Computing", amber, "Running the analysis: Cancel stops it.");
    case "drawn";     [word, c, tip] = deal("Drawn", green, "The plot is the analysis as set now.");
    case "stale";     [word, c, tip] = deal("Out of date", amber, "A setting changed since this was computed: press Compute.");
    case "failed";    [word, c, tip] = deal("Failed", red, "It failed: the line beside this and the Log tab say why.");
    case "canceled";  [word, c, tip] = deal("Canceled", gray, "Canceled before the analysis was done: press Compute.");
end
B.Grid.BackgroundColor = c{1};
B.Icon.ImageSource = fullfile(fileparts(fileparts(mfilename("fullpath"))), "icons", "status", icon + ".svg");
B.Text.Text = word;
B.Text.FontColor = c{2};
set([B.Icon B.Text], "Tooltip", tip);
if opts.Message ~= ""; obj.ChronuxStatusLabel.Text = opts.Message; end
busy = ismember(state, ["creating" "computing"]);
obj.ChronuxCancelButton.Enable = matlab.lang.OnOffSwitchState(state == "computing");
obj.ChronuxDatasetDropDown.Enable = matlab.lang.OnOffSwitchState(~busy);
if busy
    obj.ChronuxComputeButton.Enable = "off";
    obj.ChronuxCreateButton.Enable = "off";
    obj.Fig.Pointer = "watch";
    drawnow;
else
    obj.ChronuxComputeButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.ChronuxIndex) && ChronuxDataset.hasChronux());
    obj.Fig.Pointer = "arrow";
end
has = ~isempty(obj.ChronuxResult) && ismember(state, ["drawn" "stale"]);
set([obj.ChronuxSaveFigureButton obj.ChronuxSaveResultsButton], 'Enable', matlab.lang.OnOffSwitchState(has));
end
