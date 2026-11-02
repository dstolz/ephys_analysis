function state = outputState(obj, step, d)
%outputState  Whether dataset D's output of STEP was made with the config as it is.
%   STATE = pipe.outputState(STEP, D), STEP "sorting", "signals", "spikes"
%   or "export:<format>": "current", "stale" or "unknown" (EphysPipeline.
%   outputDecision says what each means). Call it only for an output that
%   exists. plan() shows the state in a row's Status ("exists: up to date" /
%   "exists: stale (options changed)"); Overwrite and OverwriteStale decide
%   what a step does with it (existingOutput).
%
%   See also EphysPipeline.outputDecision, EphysPipeline.stepHash, EphysPipeline.plan.

arguments
    obj (1,1) EphysPipeline
    step (1,1) string
    d (1,1) EphysDataset
end

[~, ~, ~, state] = EphysPipeline.outputDecision(obj.Config, step, d, false, false);
end
