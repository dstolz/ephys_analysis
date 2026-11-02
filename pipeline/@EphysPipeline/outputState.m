function state = outputState(obj, step, d)
%outputState  Whether dataset D's output of STEP was made with the config as it is.
%   STATE = pipe.outputState(STEP, D), STEP "sorting", "signals", "spikes"
%   or "export:<format>" (the same as stepHash):
%     "current"  the step's Processing record carries the hash of the options
%                it ran with (a pipeline run's, "cfg-...") and it is the hash
%                of the config as it stands (stepHash)
%     "stale"    the record has such a hash and it differs: the config, or
%                what the step reads of the dataset, changed since
%     "unknown"  no record, or one made without a pipeline (a script called
%                the writer; its hash is of the writer's own options and
%                cannot be compared)
%   Nothing is read from disk but the record in D's Processing. Call it only
%   for an output that exists. plan() shows the state in a row's Status
%   ("exists: up to date" / "exists: stale (options changed)"); Overwrite
%   and OverwriteStale decide what a step does with it (existingOutput).
%
%   See also EphysPipeline.stepHash, EphysPipeline.existingOutput, EphysPipeline.plan.

arguments
    obj (1,1) EphysPipeline
    step (1,1) string
    d (1,1) EphysDataset
end

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
if recorded == obj.stepHash(step, d)
    state = "current";
else
    state = "stale";
end
end
