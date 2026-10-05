function T = generateSynthetic(obj, opts)
%generateSynthetic  Write the Synthetic tab's dataset (the core of Generate..., no questions asked).
%   T = app.generateSynthetic() loads the source when needed, then runs
%   makeSyntheticRecording with the tab's settings (synthGeneratorArgs)
%   into <output root>\<Subject>\<Subject>_<yymmdd>_<HHmmss> (Open Ephys
%   formats: the GUI's <Subject>_<yyyy-MM-dd>_<HH-mm-ss>), named from the
%   recording's start, with a progress dialog. When that folder lies under
%   the project root the project is scanned again and the new dataset made
%   active. T is the makeSyntheticRecording result, [] when nothing was
%   written (the status line says why).
%
%   Options
%     Replace  false: an existing, non-empty folder is refused; true
%              replaces it when it holds a synthetic dataset (a
%              *_synthetic.json) and nothing else is touched
%     Scan     true: rescan when the folder is under the project root
%     Args, Folder   what synthGeneratorArgs / synthOutputFolder gave (so
%              a confirmed folder is the one written); default: ask them
%
%   See also onSynthGenerate, makeSyntheticRecording.
arguments
    obj (1,1) EphysPreprocessingApp
    opts.Replace (1,1) logical = false
    opts.Scan (1,1) logical = true
    opts.Args cell = {}
    opts.Folder (1,1) string = ""
end
T = [];
args = opts.Args; folder = opts.Folder;
if isempty(args) || folder == ""
    if obj.SynthSourceDropDown.Value ~= "task" && (isempty(obj.SynthSource) || obj.SynthSourceKey ~= obj.synthSourceKey())
        if ~obj.onSynthLoadSource(); return; end
    end
    [args, acq] = obj.synthGeneratorArgs();
    [folder, why] = obj.synthOutputFolder(acq);
    if folder == ""
        fail(obj, why);
        return
    end
end
if isfolder(folder) && numel(dir(folder)) > 2
    if ~(opts.Replace && ~isempty(dir(fullfile(folder, '*_synthetic.json'))))
        fail(obj, folder + " exists and is not empty; pick another output folder or subject.");
        return
    end
    [ok, msg] = rmdir(folder, 's');
    if ~ok
        fail(obj, "Could not remove " + folder + ": " + string(msg));
        return
    end
end
dlg = uiprogressdlg(obj.Fig, "Title", "Synthetic dataset", "Message", "Building the model ...", "Value", 0);
closer = onCleanup(@() closeDialog(dlg));
try
    T = makeSyntheticRecording(folder, args{:}, ProgressFcn=@(f, m) progress(dlg, f, m));
catch ME
    delete(closer);
    T = [];
    fail(obj, "Could not write the synthetic dataset: " + string(ME.message));
    return
end
delete(closer);

msg = sprintf("Wrote %s: %.1f s, %d channels, %d units, %d LFP component(s), %.0f MB (session %s).", ...
    folder, T.duration, numel(T.channelNames), numel(T.units), numel(T.lfp), T.bytes / 2^20, T.behaviorFile);
obj.SynthStatusLabel.Text = msg;
obj.SynthStatusLabel.FontColor = [0.16 0.45 0.25];
P = obj.Project;
root = strtrim(string(obj.RootPathField.Value));
under = root ~= "" && startsWith(lower(EphysProject.normalizeKey(folder)), lower(EphysProject.normalizeKey(root)) + "/");
if opts.Scan && under
    obj.onScan();
    P = obj.Project;
    if ~isempty(P)
        k = find(arrayfun(@(d) EphysProject.normalizeKey(d.Folder) == EphysProject.normalizeKey(folder), P.Datasets), 1);
        if ~isempty(k); obj.selectDataset(k); end
    end
    obj.SynthStatusLabel.Text = msg + " The project was scanned again; it is the active dataset.";
    obj.setStatus("Synthetic dataset written into the project: " + folder, "Trials tab: Load it to check the pairing.");
else
    obj.setStatus("Synthetic dataset written: " + folder, ...
        "Open its folder as a project (Project tab: root, Scan) to run the pipeline on it.");
end
end


function fail(obj, msg)
obj.SynthStatusLabel.Text = msg;
obj.SynthStatusLabel.FontColor = [0.70 0.15 0.10];
obj.setStatus(msg, "");
end


function progress(dlg, frac, msg)
if ~isvalid(dlg); return; end
dlg.Value = min(max(frac, 0), 1);
dlg.Message = char(msg);
drawnow limitrate;
end


function closeDialog(dlg)
try
    if isvalid(dlg); close(dlg); end
catch
end
end
