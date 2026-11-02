function [write, status, message] = existingOutput(obj, step, d, overwrite, overwriteStale)
%existingOutput  What to do with an output that is already there.
%   [WRITE, STATUS, MESSAGE] = pipe.existingOutput(STEP, D, OVERWRITE,
%   OVERWRITESTALE) for dataset D's existing output of STEP ("signals",
%   "spikes", "export:<format>"; the step's Overwrite and OverwriteStale
%   settings). WRITE is true when the step writes it again: Overwrite is
%   on, or OverwriteStale is on and the output is stale (outputState: made
%   with other options than the config's now). STATUS is the plan row's:
%     exists: overwrite              Overwrite is on
%     exists: overwrite (stale)      OverwriteStale is on and it is stale
%     exists: up to date             it was made with these options; kept
%     exists: stale (options changed)  made with other options; kept
%     exists: skip                   no record of its options; kept
%   MESSAGE is the result row's text for a kept output.
%
%   See also EphysPipeline.outputState, EphysPipeline.plan.

arguments
    obj (1,1) EphysPipeline
    step (1,1) string
    d (1,1) EphysDataset
    overwrite (1,1) logical
    overwriteStale (1,1) logical
end

state = obj.outputState(step, d);
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
