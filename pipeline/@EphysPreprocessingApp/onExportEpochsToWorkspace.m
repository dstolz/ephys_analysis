function onExportEpochsToWorkspace(obj)
%onExportEpochsToWorkspace  Put the active dataset's event-organized data in the
%   base workspace.
%   Builds EphysDataset.eventEpochs with the Export tab's epoch settings -- the
%   same struct the Export step's "epochs" format writes to
%   <Name>_epochs.mat -- for the dataset selected on the Project tab, and
%   assigns it as epochs_<name> (a valid variable name, cut to namelengthmax).
%   A variable of the same name is replaced. Nothing is written to disk.
%
%   The continuous signals come from the Signals step's extract file(s), found
%   through the dataset's outputs; run Signals first.

dlgTitle = "Epochs to the workspace";
d = obj.currentDataset();
if isempty(d)
    obj.setStatus("Export: scan a project and pick a dataset first.");
    return
end

try
    pipe = obj.buildPipeline();
catch ME
    uialert(obj.Fig, string(ME.message), dlgTitle);
    return
end
E = obj.Config.Export;

extract = EphysDataset.recordedSignalFiles(pipe.outputPathFor("signals", d));
if isempty(extract) || ~all(isfile(extract))
    extract = pipe.outputsFor(d).ExtractFiles;      % wherever it was written
end
if isempty(extract) || ~all(isfile(extract))
    uialert(obj.Fig, "No extract file for " + d.Name + " yet." + newline + newline + ...
        "Run the Signals step (it writes <Name>_extract.mat) first.", dlgTitle);
    return
end

o = EphysPipelineConfig.exportOptions(E, "epochs");
o = rmfield(o, {'Overwrite', 'MatVersion'});        % nothing is written here
if E.IncludeDetected
    spikesFile = pipe.outputPathFor("spikes", d);
    if isfile(spikesFile); o.Detected = spikesFile; else; o.Detected = false; end
end
args = namedargs2cell(o);

obj.setStatus(sprintf("Export: building epochs for %s...", d.Name));
drawnow;
try
    epochs = d.eventEpochs('Extract', extract, args{:});
catch ME
    obj.setStatus("Export: epochs for " + d.Name + " failed.");
    uialert(obj.Fig, "Could not build the epochs of " + d.Name + ":" + newline + ...
        string(ME.message), dlgTitle);
    return
end

name = string(matlab.lang.makeValidName("epochs_" + d.Name));   % also cut to namelengthmax
replaced = evalin('base', "exist('" + name + "', 'var')") == 1;
assignin('base', name, epochs);

sigTxt = "none";
if ~isempty(epochs.meta.signals); sigTxt = strjoin(epochs.meta.signals, ", "); end
msg = sprintf("The event-organized data of %s is in the base workspace as:\n\n    %s\n\n" + ...
    "Events: %d around %s (%s)\nWindow: [%g %g] s\nSignals: %s\nUnits: %d\nFields: %s", ...
    d.Name, name, epochs.event.nEpochs, epochs.event.name, epochs.event.source, ...
    epochs.event.window(1), epochs.event.window(2), sigTxt, numel(epochs.units), ...
    strjoin(string(fieldnames(epochs)), ", "));
if epochs.event.nIncomplete > 0
    msg = msg + newline + newline + sprintf( ...
        "%d epoch(s) run past the recording (EpochComplete is false for them).", ...
        epochs.event.nIncomplete);
end
if replaced
    msg = msg + newline + newline + "It replaced the variable of the same name.";
end
obj.setStatus(sprintf("Export: %d epochs of %s loaded into the workspace as %s.", ...
    epochs.event.nEpochs, d.Name, name));
uialert(obj.Fig, msg, dlgTitle, "Icon", "success");
end
