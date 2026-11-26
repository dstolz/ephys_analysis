function note = selectionNotes(obj, S, missing, legacy, opts)
%selectionNotes  Say what of a config's selection the Run ticks do not follow: a note for the status bar, a Log line each.
%   NOTE = selectionNotes(OBJ, S, MISSING, LEGACY), after selectionTicks
%   ticked the datasets listed from S (a config's Source): the keys of
%   S.Datasets that name no dataset the scan found (MISSING: "<n>
%   dataset(s) ticked in the config were not found, so they are not
%   ticked: <keys>"), and a folders-mode list of a project's keys saved
%   before folders mode had ticks of its own (LEGACY: every folder is
%   ticked, as such a config ran then; EphysAnalysisRunner.selectedFolders).
%   NOTE is "" or what the status bar adds (it starts with a space); each
%   is also said in the Log. onScan uses it.
%
%   Kept=true (tickConfigSelection: a config opened without a scan of its
%   own, the datasets listed the last scan of its source) says the missing
%   keys are not among the datasets listed and stay in the config's
%   selection until a scan (TickedNotListed, gatherSourceSection): that
%   scan is older than the config, so they may well be there.
%
%   See also selectionTicks, onScan, tickConfigSelection.
arguments
    obj
    S (1,1) struct
    missing (1,:) string
    legacy (1,1) logical
    opts.Kept (1,1) logical = false
end
note = "";
if legacy
    keys = strjoin(reshape(string(S.Datasets), 1, []), ", ");
    note = note + " The config's selection lists " + keys + ", which name no output folder: a project's dataset keys, " + ...
        "saved before folders mode had ticks of its own. Every folder is ticked, as such a config ran (see the Log tab).";
    obj.log("Selection: the config lists " + keys + ", which name no output folder (a project's dataset keys, saved before " + ...
        "folders mode had ticks of its own): every folder is ticked and runs, as such a config ran then. Save the config to keep the ticks.");
end
if isempty(missing); return; end
if opts.Kept
    note = note + sprintf(" %d dataset(s) ticked in the config are not among the datasets listed (the last scan): %s. " + ...
        "They stay in its selection until a scan (see the Log tab).", numel(missing), strjoin(missing, ", "));
    obj.log("Open: " + numel(missing) + " dataset(s) ticked in the config are not among the datasets listed, the last scan of " + ...
        "its source (not scanned again): " + strjoin(missing, ", ") + ". They stay in the config's selection until a Scan lists them.");
    return
end
note = note + sprintf(" %d dataset(s) ticked in the config were not found, so they are not ticked: %s (see the Log tab).", ...
    numel(missing), strjoin(missing, ", "));
where = "among the output folders";
if string(S.Mode) == "project"; where = "under " + string(S.Root); end
obj.log("Scan: " + numel(missing) + " dataset(s) ticked in the config were not found " + where + ": " + strjoin(missing, ", "));
end
