function out = behaviorToMat(obj, opts)
%behaviorToMat  Save the associated Epsych2 session to its own .mat file.
%   OUT = ds.behaviorToMat(Name=Value) writes the behavior data of this
%   dataset once, next to its other outputs, so the signal, spikes and
%   export files do not each carry a copy. The Epsych2 session file itself
%   is only read.
%
%   Variables in the file
%   ---------------------
%     behavior    EphysDataset.behaviorStruct: trials (table), info, meta,
%                 file, subject, startTime, nTrials, pairing (with Pairing,
%                 trials also carries the trial onset / offset columns)
%     pairing     a copy of behavior.pairing (the pairing summary: status,
%                 cuts, drops, fingerprint ...), small, so setTrialPairing
%                 can tell what a file carries without loading the trials
%     conversion  provenance: tool, created, dataset, tags, variables,
%                variableInfo, sourceFolder,
%                 behaviorFile
%
%   The file is written as -v7 (compressed, loads in milliseconds even with
%   struct-array columns such as TrialEvents: 0.04 s against 1.79 s as -v7.3
%   at 2000 trials x 8 lines) and as -v7.3 only when a variable would be
%   over 2 GB, the limit of -v7.
%
%   Options
%   -------
%     File        target (default <outputFolder>/<Name>_behavior.mat)
%     MatVersion  "-v7" (default; "-v7.3" instead when a variable would
%                 exceed 2 GB) | "-v7.3"
%     Overwrite   false (default): error if File already exists
%     Pairing     [] (default) or a pairTrials result to add to the trials
%                 (and the derived events of TrialConfig.DerivedEvents)
%     UpdateExtract  true (default): when the extract exists, bring the
%                 derived events in its events up to date
%                 (writeExtractEvents: those marked InDataset, without
%                 deriving the signals again); only with File the default
%
%   Errors with EphysDataset:behaviorToMat:NoFile when no Epsych2 session is
%   associated (BehaviorFile) or it no longer exists, unless the trials come
%   from a TDT block's epocs (behaviorSource "epocs"; behaviorFile is "").
%
%   OUT fields: file, bytes, seconds, behaviorFile, nTrials, paired (true
%   when the pairing columns were written), derivedEvents (the names of the
%   derived events written), derivedFailed (one message per derived event
%   that could not be made, see behaviorStruct) and extractFiles (the
%   extract files whose events were rewritten).
%
%   ds.Processing.behavior records how the file was made (the options, the
%   pairing, TrialConfig with the derived events' definitions) for the
%   manifest's processing block.
%
%   See also EphysDataset.behaviorStruct, EphysDataset.readBehavior,
%   DatasetOutputs.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3", "-v7"])} = "-v7"
    opts.Overwrite (1,1) logical = false
    opts.Pairing = []
    opts.UpdateExtract (1,1) logical = true
    opts.Provenance = []   % ephysProvenance() of the run writing it ([] = made here)
end
prov = opts.Provenance;
if isempty(prov); prov = ephysProvenance(); end

t0 = tic;
if obj.behaviorSource() ~= "epocs" && (obj.BehaviorFile == "" || ~isfile(obj.BehaviorFile))
    error('EphysDataset:behaviorToMat:NoFile', ...
        'No Epsych2 session is associated with %s (set BehaviorFile).', obj.Name);
end
file = opts.File;
standard = string(fullfile(obj.outputFolder(), obj.Name + "_behavior.mat"));
if file == ""
    file = standard;
end
if isfile(file) && ~opts.Overwrite
    error('EphysDataset:behaviorToMat:Exists', ...
        '%s already exists (pass Overwrite=true to replace it).', file);
end
outDir = fileparts(file);
if strlength(outDir) > 0 && ~isfolder(outDir)
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('EphysDataset:behaviorToMat:MkdirFailed', 'Could not create %s: %s', outDir, msg);
    end
end

S = struct();
S.behavior = obj.behaviorStruct(Pairing=opts.Pairing);
S.pairing = S.behavior.pairing;
S.conversion = struct( ...
    'tool',         "EphysDataset.behaviorToMat", ...
    'created',      string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',      obj.Name, ...
    'tags',         {obj.Tags}, ...
    'variables',    DatasetVariables.values(obj.Variables), ...
    'variableInfo', {DatasetVariables.info(obj.Variables)}, ...
    'sourceFolder', obj.Folder, ...
    'behaviorFile', obj.BehaviorFile);
S.conversion.provenance = prov;
matVersion = opts.MatVersion;
if matVersion == "-v7" && any(structfun(@variableBytes, S) > 2^31 - 2^20)
    matVersion = "-v7.3";   % -v7 stores no variable over 2 GB
end
opts.MatVersion = matVersion;   % what the manifest records is what was written
EphysDataset.saveAtomically(file, S, matVersion);

xf = strings(1, 0);
if opts.UpdateExtract && strcmpi(file, standard)
    xf = obj.writeExtractEvents(S.behavior.derivedEvents);
end
d = dir(file);
out = struct('file', file, 'bytes', d.bytes, 'seconds', toc(t0), ...
    'behaviorFile', obj.BehaviorFile, 'nTrials', S.behavior.nTrials, ...
    'paired', ~isempty(opts.Pairing));
out.derivedEvents = reshape(string({S.behavior.derivedEvents.name}), 1, []);
out.derivedFailed = reshape(string({S.behavior.derivedEventsFailed.message}), 1, []);
out.extractFiles = xf;

% How the file was made, for the manifest (Processing): the options, the
% pairing taken (its large per-trial columns noted, not copied), the trial
% and line settings (TrialConfig, the derived events' definitions with it)
% and what came of them.
r = EphysDataset.processingRecord("file", file, prov, rmfield(opts, 'Pairing'));
r.source = obj.BehaviorFile;   % "" for a TDT block's epocs
r.pairing = [];
if isstruct(opts.Pairing) && isscalar(opts.Pairing); r.pairing = EphysDataset.optionsRecord(opts.Pairing); end
r.trial_config = EphysDataset.optionsRecord(obj.TrialConfig);
r.n_trials = out.nTrials;
r.derived_events = cellstr(out.derivedEvents);
r.derived_failed = cellstr(out.derivedFailed);
r.extract_files = cellstr(xf);
obj.Processing.behavior = r;
end


function b = variableBytes(x)
%variableBytes  Bytes MATLAB holds the variable X in (what -v7 limits to 2 GB, before compression).
w = whos('x');
b = w.bytes;
end
