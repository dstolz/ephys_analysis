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
%     conversion  provenance: tool, created, dataset, sourceFolder,
%                 behaviorFile
%
%   Options
%   -------
%     File        target (default <outputFolder>/<Name>_behavior.mat)
%     MatVersion  "-v7.3" (default) | "-v7"
%     Overwrite   false (default): error if File already exists
%     Pairing     [] (default) or a pairTrials result to add to the trials
%
%   Errors with EphysDataset:behaviorToMat:NoFile when no Epsych2 session is
%   associated (BehaviorFile) or it no longer exists.
%
%   OUT fields: file, bytes, seconds, behaviorFile, nTrials, paired (true
%   when the pairing columns were written).
%
%   See also EphysDataset.behaviorStruct, EphysDataset.readBehavior,
%   DatasetOutputs.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3", "-v7"])} = "-v7.3"
    opts.Overwrite (1,1) logical = false
    opts.Pairing = []
end

t0 = tic;
if obj.BehaviorFile == "" || ~isfile(obj.BehaviorFile)
    error('EphysDataset:behaviorToMat:NoFile', ...
        'No Epsych2 session is associated with %s (set BehaviorFile).', obj.Name);
end
file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + "_behavior.mat"));
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
S.conversion = struct( ...
    'tool',         "EphysDataset.behaviorToMat", ...
    'created',      string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',      obj.Name, ...
    'sourceFolder', obj.Folder, ...
    'behaviorFile', obj.BehaviorFile);
EphysDataset.saveAtomically(file, S, opts.MatVersion);

d = dir(file);
out = struct('file', file, 'bytes', d.bytes, 'seconds', toc(t0), ...
    'behaviorFile', obj.BehaviorFile, 'nTrials', S.behavior.nTrials, ...
    'paired', ~isempty(opts.Pairing));
end
