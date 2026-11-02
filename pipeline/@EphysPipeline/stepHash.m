function h = stepHash(obj, step, d)
%stepHash  A hash of the config options the output of STEP is made with, for dataset D.
%   H = pipe.stepHash(STEP, D) is EphysPipeline.configHash of this pipeline's
%   config. The writers record it as options_hash of the step's Processing
%   record (provenanceFor), and outputState compares it with what is recorded.
%
%   See also EphysPipeline.configHash, EphysPipeline.outputState, EphysPipeline.plan.

arguments
    obj (1,1) EphysPipeline
    step (1,1) string
    d (1,1) EphysDataset
end

h = EphysPipeline.configHash(obj.Config, step, d);
end
