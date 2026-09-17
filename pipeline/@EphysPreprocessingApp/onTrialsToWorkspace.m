function onTrialsToWorkspace(obj, source)
%onTrialsToWorkspace  Put the active dataset's behavior data in the base workspace.
%   source "epsych" loads the associated Epsych2 session file as saved (a
%   struct of its variables: Data, Info) as epsych_<name>; "behavior" loads
%   the behavior struct of <name>_behavior.mat (EphysDataset.behaviorStruct:
%   trials with the pairing columns, info, meta, pairing, ...) as
%   behavior_<name> (made a valid name, cut to namelengthmax). A variable of
%   the same name is replaced. An alert and the status bar give the
%   variable's name.
arguments
    obj (1,1) EphysPreprocessingApp
    source (1,1) string {mustBeMember(source, ["epsych" "behavior"])}
end
dlgTitle = "Load into the workspace";
d = obj.currentDataset();
if isempty(d)
    obj.setStatus("Trials: scan a project and pick a dataset first.");
    return
end
if source == "epsych"
    file = d.BehaviorFile;
    what = "Epsych2 session";
    if file == "" || ~isfile(file)
        uialert(obj.Fig, d.Name + " has no Epsych2 session associated (Project tab).", dlgTitle);
        return
    end
else
    file = string(fullfile(d.outputFolder(), d.Name + "_behavior.mat"));   % EphysPipeline.outputPathFor("behavior")
    what = "behavior data";
    if ~isfile(file)
        uialert(obj.Fig, "No behavior file yet:" + newline + file + newline + newline + ...
            "Run the behavior step or press Write behavior .mat first.", dlgTitle);
        return
    end
end

try
    if source == "epsych"
        value = load(file);
        nTrials = numel(value.Data);
    else
        L = load(file, 'behavior');
        value = L.behavior;
        nTrials = value.nTrials;
    end
catch ME
    uialert(obj.Fig, "Could not load " + file + ":" + newline + string(ME.message), dlgTitle);
    return
end

name = string(matlab.lang.makeValidName(source + "_" + d.Name));   % also cut to namelengthmax
replaced = evalin('base', "exist('" + name + "', 'var')") == 1;
assignin('base', name, value);

msg = sprintf("The %s of %s is in the base workspace as:\n\n    %s\n\nFields: %s\nTrials: %d\nFile: %s", ...
    what, d.Name, name, strjoin(string(fieldnames(value)), ", "), nTrials, file);
if replaced
    msg = msg + newline + newline + "It replaced the variable of the same name.";
end
obj.setStatus(sprintf("Trials: %s of %s loaded into the workspace as %s.", what, d.Name, name));
uialert(obj.Fig, msg, dlgTitle, "Icon", "success");
end
