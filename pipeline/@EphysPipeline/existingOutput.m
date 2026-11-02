function [write, status, message] = existingOutput(obj, step, d, overwrite, overwriteStale)
%existingOutput  What to do with an output that is already there.
%   [WRITE, STATUS, MESSAGE] = pipe.existingOutput(STEP, D, OVERWRITE,
%   OVERWRITESTALE) is EphysPipeline.outputDecision on this pipeline's config.
%
%   See also EphysPipeline.outputDecision, EphysPipeline.outputState, EphysPipeline.plan.

arguments
    obj (1,1) EphysPipeline
    step (1,1) string
    d (1,1) EphysDataset
    overwrite (1,1) logical
    overwriteStale (1,1) logical
end

[write, status, message] = EphysPipeline.outputDecision(obj.Config, step, d, overwrite, overwriteStale);
end
