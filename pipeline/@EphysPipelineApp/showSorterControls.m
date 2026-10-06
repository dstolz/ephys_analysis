function showSorterControls(obj, S)
%showSorterControls  Show the parameters of the sorter the Sorter drop-down names.
%   Kilosort4: its parameter rows, as they always were. A SpikeInterface
%   sorter: those rows hide and SIPanel shows that sorter's parameters
%   (Sorting.SIParams.<sorter> of the working config, else SpikeInterface's
%   defaults) beside their descriptions. The step's check box (here and on
%   the Run tab), the Run tab's runs-at-once label, the Artifacts tab's
%   "Erase in sorting", the note on artifacts, the log panel and "Use auto"
%   name the sorter. SIParamsShown
%   then names the sorter whose parameters the text area holds, which
%   gatherSortingSection stores them under.
%
%   S is the Sorting section the parameters come from (default the
%   working config's; applySortingSection passes the one it shows).
%
%   See also onSorterChanged, buildSortingTab.
if isempty(obj.SortSorterDropDown) || ~isvalid(obj.SortSorterDropDown); return; end
if nargin < 2; S = obj.Config.Sorting; end
sorter = string(obj.SortSorterDropDown.Value);
si = sorter ~= "kilosort4";
what = EphysDataset.sorterLabel(sorter);
set(obj.KS4ParamWidgets(isvalid(obj.KS4ParamWidgets)), "Visible", ~si);
obj.SIPanel.Visible = si;
obj.SortEnableCheckBox.Text = "Enable the Sorting step (" + what + ")";
if ~isempty(obj.RunSortingCheckBox) && isvalid(obj.RunSortingCheckBox)   % Run tab's Steps panel
    obj.RunSortingCheckBox.Text = "Sorting: " + what;
end
if ~isempty(obj.RunKSAtOnceLabel) && isvalid(obj.RunKSAtOnceLabel)
    obj.RunKSAtOnceLabel.Text = what + " runs at once:";
end
if ~isempty(obj.ArtApplySortingCheckBox) && isvalid(obj.ArtApplySortingCheckBox)   % Artifacts tab
    short = what;
    if si; short = sorter; end   % no "(SpikeInterface)" inside the parentheses
    obj.ArtApplySortingCheckBox.Text = "Erase in sorting (in the .bin " + short + " sorts)";
end
obj.SortNoteLabel.Text = "Artifact silencing (manual periods always; automatic detection when enabled) " + ...
    "is configured on the Artifacts tab, the way they are erased included; those periods are erased in " + ...
    "the .bin " + what + " sorts.";
obj.KSLogPanel.Title = what + " log (background runs stream here)";
folder = "kilosort4";
if si; folder = "si_" + sorter; end
obj.SortUseAutoButton.Tooltip = "Back to the run under <output root>/<Name>/" + folder + ".";

if ~si
    obj.SIParamsShown = "";
    return
end
obj.SIParamsShown = sorter;
txt = EphysPipelineConfig.siParams(S, sorter);
defaults = obj.siDefaultParams(sorter);
if strtrim(txt) == ""; txt = defaults; end
if txt == ""; txt = "{" + newline + "}"; end
obj.SIParamsArea.Value = cellstr(splitlines(txt));

k = [];
if ~isempty(obj.SISorters); k = find([obj.SISorters.name] == sorter, 1); end
if isempty(k)
    obj.SIParamsTitle.Text = sorter + " parameters";
    obj.SIParamsHelpArea.Value = {char("SpikeInterface's defaults for " + sorter + " are not known here: " + ...
        "click ""Find SpikeInterface sorters"" (with the Python exe of the env that has it). " + ...
        "The parameters on the left go over the defaults when it runs.")};
else
    s = obj.SISorters(k);
    v = "";
    if s.version ~= ""; v = " " + s.version; end
    obj.SIParamsTitle.Text = sorter + v + " parameters (SpikeInterface " + obj.SIVersion + ")";
    T = s.descriptions;
    lines = strings(0, 1);
    for i = 1:height(T)
        lines(end+1) = T.Parameter(i) + " = " + T.Default(i); %#ok<AGROW>
        if T.Description(i) ~= ""
            lines(end+1) = "    " + T.Description(i); %#ok<AGROW>
        end
        lines(end+1) = ""; %#ok<AGROW>
    end
    if isempty(lines); lines = "(no descriptions)"; end
    obj.SIParamsHelpArea.Value = cellstr(lines);
end
obj.SIInfoLabel.Text = "Runs spikeinterface.run_sorter(""" + sorter + """) on the <Name>.bin the Sorting step writes " + ...
    "(the artifact periods erased; the common reference applied once: when the .bin carries it, the " + ...
    "sorter's own is kept out). Writes phy files to <Name>/si_" + sorter + "/, each unit labelled good or " + ...
    "mua by the good-unit criteria (Review tab). The parameters go over SpikeInterface's defaults; " + ...
    "names the sorter does not have are dropped (see the run's log).";
end
