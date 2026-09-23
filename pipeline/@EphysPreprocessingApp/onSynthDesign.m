function onSynthDesign(obj, action)
%onSynthDesign  The Synthetic tab's editing buttons.
%   ACTION: "addUnit" | "removeUnit" | "addOscillation" | "addEvoked" |
%   "removeLFP" | "builtIn" | "clear" | "addLine" | "removeLine" | "load" |
%   "save" | "browseOutput". New units and LFP components are linked to Stim
%   when the source has it, else to its trial line; Remove takes the
%   selected rows (the last row when none is selected).
arguments
    obj (1,1) EphysPreprocessingApp
    action (1,1) string
end
[lines, ~, trialLine] = obj.synthSourceLists();
event = trialLine;
if ismember("Stim", lines); event = "Stim"; elseif ~isempty(lines) && ~ismember(trialLine, lines); event = lines(1); end
D = obj.gatherSynthDesign();
switch action
    case "addUnit"
        r = SyntheticDesign.newUnit(nextName("u", D.Units.Name), event);
        r.Channel = min(height(D.Units) + 1, obj.SynthChannelsField.Value);
        D.Units = [D.Units; r];
    case "removeUnit"
        D.Units(selectedRows(obj.SynthUnitsTable, height(D.Units)), :) = [];
    case "addOscillation"
        D.LFP = [D.LFP; SyntheticDesign.newLFP("oscillation", event, nextName("gamma", D.LFP.Name))];
    case "addEvoked"
        D.LFP = [D.LFP; SyntheticDesign.newLFP("evoked", event, nextName("evoked", D.LFP.Name))];
    case "removeLFP"
        D.LFP(selectedRows(obj.SynthLFPTable, height(D.LFP)), :) = [];
    case "builtIn"
        B = SyntheticDesign.builtIn(obj.SynthChannelsField.Value, Event=event);
        B.Background = D.Background;
        D = B;
    case "clear"
        D.Units = SyntheticDesign.unitTable(0);
        D.LFP = SyntheticDesign.lfpTable(0);
    case "addLine"
        C = obj.SynthLinesTable.Data;
        if isempty(C); C = cell(0, 3); end
        obj.SynthLinesTable.Data = [C; {char("Line" + (size(C, 1) + 1)), '0', '100'}];
        obj.onSynthControlsChanged("schedule");
        return
    case "removeLine"
        C = obj.SynthLinesTable.Data;
        C(selectedRows(obj.SynthLinesTable, size(C, 1)), :) = [];
        obj.SynthLinesTable.Data = C;
        obj.onSynthControlsChanged("schedule");
        return
    case "load"
        [f, p] = uigetfile({'*.json', 'Synthetic design (*.json)'}, "Load a synthetic design", char(startFolder(obj)));
        figure(obj.Fig);
        if isequal(f, 0); return; end
        try
            L = SyntheticDesign.load(fullfile(p, f));
        catch ME
            uialert(obj.Fig, string(ME.message), "Load design");
            return
        end
        D = L;
    case "save"
        [f, p] = uiputfile({'*.json', 'Synthetic design (*.json)'}, "Save the synthetic design", ...
            fullfile(char(startFolder(obj)), 'synthetic_design.json'));
        figure(obj.Fig);
        if isequal(f, 0); return; end
        try
            D.save(fullfile(p, f));
            obj.SynthStatusLabel.Text = "Design saved to " + string(fullfile(p, f)) + ".";
        catch ME
            uialert(obj.Fig, string(ME.message), "Save design");
        end
        return
    case "browseOutput"
        p = uigetdir(char(startFolder(obj)), "Folder under which to write synthetic datasets");
        figure(obj.Fig);
        if isequal(p, 0); return; end
        obj.SynthOutputField.Value = p;
        obj.onSynthControlsChanged();
        return
    otherwise
        error('EphysPreprocessingApp:onSynthDesign', 'Unknown action "%s".', action);
end
obj.applySynthDesign(D);
obj.onSynthControlsChanged();
end


function rows = selectedRows(tbl, n)
rows = [];
if ~isempty(tbl.Selection); rows = unique(tbl.Selection(:, 1)).'; end
if isempty(rows) && n > 0; rows = n; end
rows = rows(rows >= 1 & rows <= n);
end


function name = nextName(stem, taken)
k = numel(taken) + 1;
while ismember(stem + k, taken); k = k + 1; end
name = stem + k;
end


function p = startFolder(obj)
p = string(obj.SynthOutputField.Value);
if p == "" || ~isfolder(p); p = obj.synthOutputRoot(); end
if p == "" || ~isfolder(p); p = string(pwd); end
end
