function h = configHash(c, step, d)
%configHash  A hash of the config options the output of STEP is made with, for dataset D.
%   H = EphysPipeline.configHash(C, STEP, D), C the config or a struct with
%   the sections STEP reads (a standalone script's stepOptions; a pipeline's is
%   pipe.stepHash), STEP "sorting", "signals", "spikes" or
%   "export:<format>": "cfg-" and 16 hexadecimal digits
%   (EphysDataset.optionsHash) of the step's section of the config - but
%   for what only says where or whether the file is written (Enabled,
%   Overwrite, OverwriteStale, OutputDir, Suffix, MatVersion, how a sort is
%   run: Execution, MaxConcurrent, Devices, DryRun, SkipExisting, PythonExe,
%   CondaEnv, BinDir) - with what else decides the result for D: the common
%   reference, the channels left out, the artifact periods (the Artifacts
%   section and D's manual periods and moved bounds) when the step erases
%   them, the probe when the step reads its geometry and, for an export,
%   the sorted units folder and the signals it reads (their own hash).
%
%   The writers record it as options_hash of the step's Processing record
%   (they get it in the Provenance they are called with, see
%   EphysDataset.processingRecord); outputState compares the recorded
%   hash with this one, so a step whose config changed since is "stale".
%   The "cfg-" prefix tells it from the hash a writer makes of its own
%   options when it is called without the pipeline.
%
%   See also EphysPipeline.stepHash, EphysPipeline.outputDecision, EphysPipeline.plan,
%   EphysDataset.optionsHash.

arguments
    c (1,1)
    step (1,1) string
    d (1,1) EphysDataset
end

key = extractBefore(step + ":", ":");
o = struct('step', char(step));
switch key
    case "signals"
        G = without(c.Signals, ["Enabled" "Overwrite" "OverwriteStale" "OutputDir" "Suffix" "MatVersion"]);
        o.Signals = G;
        o.Reference = c.Reference;
        o.Exclude = d.excludedChannels();
        if G.BlankArtifacts
            o.Artifacts = artifactPart(c, d);
        end
    case "spikes"
        K = without(c.Spikes, ["Enabled" "Overwrite" "OverwriteStale" "OutputDir" "Suffix" "MatVersion"]);
        o.Spikes = K;
        o.Reference = c.Reference;
        o.Exclude = d.excludedChannels();
        if K.ArtifactMode ~= "none"
            o.Artifacts = artifactPart(c, d);
        end
        if K.Coincidence ~= "none"
            o.Probe = EphysPipeline.resolveProbe(c.Probe, d);
        end
    case "sorting"
        S = without(c.Sorting, ["Enabled" "Execution" "MaxConcurrent" "Devices" "DryRun" "SkipExisting" ...
            "PythonExe" "CondaEnv" "BinDir"]);
        if S.Sorter == "kilosort4"
            S = without(S, ["SIParams" "Quality"]);
        else
            S.SIParams = EphysPipelineConfig.siParams(c.Sorting);   % this sorter's own
        end
        o.Sorting = S;
        o.Reference = c.Reference;
        o.Exclude = d.excludedChannels();
        o.Artifacts = artifactPart(c, d);
        o.Probe = EphysPipeline.resolveProbe(c.Probe, d);
    case "export"
        E = without(c.Export, ["Enabled" "Overwrite" "OverwriteStale" "OutputDir"]);
        o.Export = E;
        o.Probe = EphysPipeline.resolveProbe(c.Probe, d);
        o.Signals = recordedHash(d, "signals");
        if E.IncludeUnits
            o.Units = string(d.sortingResultsDir());
            o.Sorted = recordedHash(d, "sorting");
        end
    otherwise
        error('EphysPipeline:BadStep', 'configHash: "%s" is not a step that writes an output.', step);
end
h = "cfg-" + EphysDataset.optionsHash(o);
end


function s = without(s, names)
%without  The section S less the fields NAMES that it has.
s = rmfield(s, intersect(fieldnames(s), cellstr(names)));
end


function a = artifactPart(c, d)
%artifactPart  What decides the artifact periods a step erases: the Artifacts section and D's own periods.
a = struct('Config', c.Artifacts, 'Manual', d.ManualArtifacts, 'Adjusted', d.ArtifactAdjustments);
end


function h = recordedHash(d, key)
%recordedHash  The options_hash of D's Processing record KEY, "" when it has none.
h = "";
r = d.Processing.(key);
if isstruct(r) && isscalar(r) && isfield(r, 'options_hash')
    h = string(r.options_hash);
end
end
