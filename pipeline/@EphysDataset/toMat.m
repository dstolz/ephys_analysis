function out = toMat(obj, opts)
%toMat  Derive LFP / MUA / SPIKE / AUX signals and save them to .mat file(s).
%   OUT = ds.toMat(Name=Value) runs EphysDataset.deriveSignals and saves its
%   outputs -- variables Y, events and info, plus a small "conversion"
%   provenance struct -- to one MAT-file, or with SeparateFiles=true to one
%   MAT-file per signal type. The recording files are only read. Behavior
%   data is not stored here; it has its own file (behaviorToMat).
%
%   Separate files are named <File without .mat>_<TYPE>.mat (see
%   EphysDataset.signalFiles), e.g. rec_extract_LFP.mat. Each has the same
%   variables as the combined file, but Y holds only that signal (the other
%   Y fields are single([])) and info only that signal's sub-struct, so every
%   reader of the combined file reads it too. The derivation runs once.
%   AUX (the accelerometer inputs) is written only when the recording has
%   them: a requested AUX that is absent gets no _AUX file.
%
%   The file is written to "~<name>.partial.mat" next to the target and
%   renamed only after save() finishes without warnings and every variable is
%   confirmed present, so a failed or cancelled run never leaves a
%   complete-looking file behind. (save() reports a variable it could not
%   store, e.g. over 2 GB with -v7, as a warning and omits it; that is treated
%   as a failure here.)
%
%   Options
%   -------
%     File           target .mat path (default:
%                    <outputFolder()>/<Name>_extract.mat); the base name
%                    of the per-type files when SeparateFiles
%     SeparateFiles  false (default): one file; true: one file per signal
%     SignalOptions  struct of deriveSignals options (dataTypeOut, LFP_Fs,
%                    keepAmpChannels, ...); omitted fields use its defaults
%                    (labelField, lineNames and invertedLines: TrialConfig)
%     MatVersion     "-v7.3" (default, any size) | "-v7"
%     Overwrite      false (default): error if File (or any per-type
%                    file) already exists
%     ProgressFcn    as in deriveSignals, called as ProgressFcn(nDone, nTotal,
%                    message); the save is counted as one extra step. It may
%                    throw to abort; once the file is complete, an error from
%                    the final "Done" notification is ignored.
%
%   OUT fields: file (one per file written, in dataTypeOut order when
%   SeparateFiles), types (the signal type(s) in each file), bytes (per file), seconds, matVersion, recordingFormat, origFs,
%   signals (struct array: name, nSamples, nChannels, class, Fs), events
%   (struct array: name, count), badChannels (the columns actually
%   interpolated, from info.importOptions; info.badChannels says how).
%
%   See also EphysDataset.deriveSignals, INTAN2MATLAB.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.SignalOptions (1,1) struct = struct()
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3", "-v7"])} = "-v7.3"
    opts.SeparateFiles (1,1) logical = false
    opts.Overwrite (1,1) logical = false
    opts.ProgressFcn = []
end

file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + "_extract.mat"));
end
if opts.SeparateFiles
    if isfield(opts.SignalOptions, 'dataTypeOut')
        types = unique(string(opts.SignalOptions.dataTypeOut), 'stable');
    else
        types = "LFP";   % deriveSignals' default
    end
    files = EphysDataset.signalFiles(file, types);
else
    files = file;
end
existing = files(isfile(files));
if ~isempty(existing) && ~opts.Overwrite
    error('EphysDataset:toMat:Exists', ...
        '%s already exists (pass Overwrite=true to replace it).', strjoin(existing, ', '));
end
outDir = fileparts(file);
if strlength(outDir) > 0 && ~isfolder(outDir)
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('EphysDataset:toMat:MkdirFailed', 'Could not create %s: %s', outDir, msg);
    end
end
if isfield(opts.SignalOptions, 'ProgressFcn')
    error('EphysDataset:toMat:ProgressFcn', ...
        'Pass ProgressFcn to toMat itself, not inside SignalOptions.');
end

% Forward progress with one extra step for the save: deriveSignals' final
% (n, n, "Done") becomes (n, n+1, "Saving ...").
steps = containers.Map({'total'}, {NaN});
cb = [];
if ~isempty(opts.ProgressFcn)
    cb = @(d, n, m) forwardProgress(opts.ProgressFcn, steps, d, n, m, strjoin(files, ", "));
end

t0 = tic;
args = namedargs2cell(opts.SignalOptions);
[Y, ev, info] = obj.deriveSignals(args{:}, 'ProgressFcn', cb);

conversion = struct( ...
    'tool',            "EphysDataset.toMat (deriveSignals / intan2matlab)", ...
    'created',         string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',         obj.Name, ...
    'sourceFolder',    obj.Folder, ...
    'recordingFormat', obj.RecordingFormat, ...
    'matFileVersion',  opts.MatVersion, ...
    'matlabVersion',   string(version));
if opts.SeparateFiles
    written = isfield(info, cellstr(types));   % a requested AUX may be absent
    files = files(written);
    types = types(written);
end
bytes = zeros(1, numel(files));
for k = 1:numel(files)
    S = struct();
    if opts.SeparateFiles
        [S.Y, S.info] = onlySignal(Y, info, types(k));
    else
        S.Y = Y;
        S.info = info;
    end
    S.events = ev;
    S.conversion = conversion;
    EphysDataset.saveAtomically(files(k), S, opts.MatVersion);
    clear S
    d = dir(files(k));
    bytes(k) = d.bytes;
end

out = struct();
out.file            = files;
if opts.SeparateFiles
    out.types       = types;
else
    out.types       = strjoin(string(info.importOptions.dataTypeOut(isfield(info, ...
        cellstr(info.importOptions.dataTypeOut)))), "+");
end
out.bytes           = bytes;
out.seconds         = toc(t0);
out.matVersion      = opts.MatVersion;
out.recordingFormat = obj.RecordingFormat;
out.origFs          = info.origFs;
out.signals         = signalSummary(Y, info);
out.events          = eventSummary(ev);
out.badChannels     = info.importOptions.badChannels;

if ~isempty(obj.Manifest) && isa(obj.Manifest, 'Manifest')
    obj.Manifest.add("toMat", "Wrote derived signals .mat", ...
        struct('file', files, 'dataTypeOut', info.importOptions.dataTypeOut, ...
        'bytes', out.bytes));
end

if ~isempty(opts.ProgressFcn)
    try
        n1 = steps('total');
        opts.ProgressFcn(n1, n1, "Done");
    catch
        % The file is already complete; a cancel raised here must not turn a
        % finished conversion into a reported failure.
    end
end
end


function [Ys, infoS] = onlySignal(Y, info, type)
%onlySignal  Y / info reduced to one signal type (the others emptied / removed).
Ys = Y;
infoS = info;
for f = ["LFP" "MUA" "SPIKE" "AUX"]
    if f ~= type
        Ys.(f) = single([]);
        if isfield(infoS, f); infoS = rmfield(infoS, f); end
    end
end
end


function forwardProgress(fcn, steps, d, n, m, file)
%forwardProgress  Relay deriveSignals progress with one extra (save) step.
steps('total') = n + 1;   % containers.Map is a handle: visible to toMat
if d >= n
    fcn(n, n + 1, "Saving " + file);
else
    fcn(d, n + 1, m);
end
end


function s = signalSummary(Y, info)
%signalSummary  Size / class / rate of each derived signal that was requested.
s = struct('name', {}, 'nSamples', {}, 'nChannels', {}, 'class', {}, 'Fs', {});
for f = ["LFP" "MUA" "SPIKE" "AUX"]
    if isfield(info, f)   % info.<type> exists only for requested types
        X = Y.(f);
        s(end+1) = struct('name', f, 'nSamples', size(X, 1), ...
            'nChannels', size(X, 2), 'class', string(class(X)), ...
            'Fs', info.(f).Fs); %#ok<AGROW>
    end
end
end


function s = eventSummary(events)
%eventSummary  Number of [on off] intervals per digital-input line.
fn = fieldnames(events);
s = struct('name', {}, 'count', {});
for k = 1:numel(fn)
    s(end+1) = struct('name', string(fn{k}), 'count', size(events.(fn{k}), 1)); %#ok<AGROW>
end
end
