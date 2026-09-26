function onTrialsToWorkspace(obj, source)
%onTrialsToWorkspace  Put the active dataset's behavior data in the base workspace.
%   source "epsych" loads the dataset's trial source as read: the associated
%   Epsych2 session file as saved (a struct of its variables: Data, Info) as
%   epsych_<name>, or, for a TDT block whose trials are epocs, its epoc
%   stores (TDTReader.readEpocs: one element per store) as epocs_<name>;
%   "behavior" loads
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
src = "";
if source == "epsych"
    src = trialSource(d);
    switch src
        case "epsych2"
            file = d.BehaviorFile;
            what = "Epsych2 session";
        case "epocs"
            file = d.Reader.Folder;
            what = "TDT epocs";
        otherwise
            uialert(obj.Fig, d.Name + " has no trial source: no Epsych2 session associated (Project tab), " + ...
                "and no TDT epoc store named as the trial line.", dlgTitle);
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

prefix = source;
try
    if src == "epsych2"
        value = load(file);
        nTrials = numel(value.Data);
    elseif src == "epocs"
        value = d.Reader.readEpocs();
        nTrials = height(d.readBehavior());
        prefix = "epocs";
    else
        L = load(file, 'behavior');
        value = L.behavior;
        nTrials = value.nTrials;
    end
catch ME
    uialert(obj.Fig, "Could not load " + file + ":" + newline + string(ME.message), dlgTitle);
    return
end

name = string(matlab.lang.makeValidName(prefix + "_" + d.Name));   % also cut to namelengthmax
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
