function [write, status, message, state] = outputDecision(c, step, d, overwrite, overwriteStale)
%outputDecision  What to do with an output that is already there.
%   [WRITE, STATUS, MESSAGE, STATE] = EphysPipeline.outputDecision(C, STEP, D,
%   OVERWRITE, OVERWRITESTALE) for dataset D's existing output of STEP
%   ("signals", "spikes", "export:<format>"; the step's Overwrite and
%   OverwriteStale settings), C the config or a struct with the sections STEP
%   reads (a standalone script's stepOptions; a pipeline's is
%   pipe.existingOutput). WRITE is true when the step writes it again:
%   Overwrite is on, or OverwriteStale is on and the output is stale. STATUS
%   is the plan row's:
%     exists: overwrite              Overwrite is on
%     exists: overwrite (stale)      OverwriteStale is on and it is stale
%     exists: up to date             it was made with these options; kept
%     exists: stale (options changed)  made with other options; kept
%     exists: skip                   no record of its options; kept
%   MESSAGE is the result row's text for a kept output. STATE says whether it
%   was made with the config as it is:
%     "current"  the step's Processing record carries the hash of the options
%                it ran with (a pipeline run's or a standalone script's,
%                "cfg-...") and it is the hash of C as it stands (configHash)
%     "stale"    the record has such a hash and it differs: the config, or
%                what the step reads of the dataset, changed since
%     "unknown"  no record, or one made without a config (a script called
%                the writer; its hash is of the writer's own options and
%                cannot be compared)
%   Nothing is read from disk but the record in D's Processing.
%
%   See also EphysPipeline.existingOutput, EphysPipeline.outputState,
%   EphysPipeline.configHash, EphysPipeline.plan.

arguments
    c (1,1)
    step (1,1) string
    d (1,1) EphysDataset
    overwrite (1,1) logical
    overwriteStale (1,1) logical
end

state = recordState(c, step, d);
write = overwrite || (overwriteStale && state == "stale");
message = "output exists (Overwrite is off)";
if overwrite
    status = "exists: overwrite";
elseif write
    status = "exists: overwrite (stale)";
elseif state == "current"
    status = "exists: up to date";
    message = "output exists and is up to date (Overwrite is off)";
elseif state == "stale"
    status = "exists: stale (options changed)";
    message = "output exists, made with other options (stale); Overwrite or OverwriteStale writes it again";
else
    status = "exists: skip";
end
end


function state = recordState(c, step, d)
%recordState  STATE of outputDecision, from D's Processing record of STEP.
key = extractBefore(step + ":", ":");
if key == "export"
    key = extractAfter(step, ":");   % the format: Processing.nwb
end
state = "unknown";
if ~isfield(d.Processing, key); return; end
r = d.Processing.(key);
if ~(isstruct(r) && isscalar(r) && isfield(r, 'options_hash')); return; end
recorded = string(r.options_hash);
if ~startsWith(recorded, "cfg-"); return; end
if recorded == EphysPipeline.configHash(c, step, d)
    state = "current";
else
    state = "stale";
end
end
