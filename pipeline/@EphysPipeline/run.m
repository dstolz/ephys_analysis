function R = run(obj, opts)
%run  Validate, plan, then execute the enabled steps in order.
%   R = pipe.run() returns the Results table. Errors in the config
%   (validate) or in the plan (duplicate outputs, per-dataset "error:" rows)
%   stop before anything is written (EphysPipeline:ConfigInvalid /
%   EphysPipeline:PlanInvalid; see checkRun). Per-dataset failures inside a
%   step are recorded as "error" rows and the run continues; cancel() stops
%   the run at the next progress notification and returns what was done.
%   Each step starts with one progress event of its own (dataset "", index
%   0, message "starting"), so a listener sees every step begin, including
%   the ones that report nothing else.
%
%   Options
%     Steps    subset of EphysPipelineConfig.StepNames to run, in the
%              canonical order ([] = the enabled steps)
%     DryRun   true: every step runs with DryRun, so nothing is written
%              (no manifest, cache, behavior or output file) and no artifact
%              detection streams the recording; each step records "dry run"
%              rows saying what it would do. Sorting writes its config /
%              script only (runKilosort DryRun).
%
%   See also EphysPipeline.checkRun, EphysPipeline.plan, EphysPipelineConfig.validate.

arguments
    obj (1,1) EphysPipeline
    opts.Steps (1,:) string = string.empty(1,0)
    opts.DryRun (1,1) logical = false
end

c = obj.Config;
steps = opts.Steps;
if isempty(steps)
    steps = c.enabledSteps();
else
    bad = setdiff(steps, EphysPipelineConfig.StepNames);
    if ~isempty(bad)
        error('EphysPipeline:BadStep', 'Unknown step(s): %s', strjoin(bad, ', '));
    end
    steps = EphysPipelineConfig.StepNames(ismember(EphysPipelineConfig.StepNames, steps));
end
obj.checkRun(Steps=steps);

obj.reset();
obj.log("=== Pipeline '%s': %d dataset(s); steps: %s%s ===", c.Name, numel(obj.DatasetIdx), ...
    strjoin(steps, ", "), ternary(opts.DryRun, " [DRY RUN]", ""));
if isempty(obj.DatasetIdx)
    obj.log("No datasets selected; nothing to do.");
    R = obj.Results;
    return
end

t0 = tic;
for step = steps
    obj.log("--- step: %s ---", step);
    try
        if ~obj.CancelRequested   % once cancelled, the step records its datasets as "cancelled" itself
            obj.progress(step, "", 0, numel(obj.DatasetIdx), 0, 1, "starting");
        end
        switch step
            case "probe";     obj.checkProbes(DryRun=opts.DryRun);
            case "behavior";  obj.checkBehavior(DryRun=opts.DryRun);
            case "artifacts"; obj.runArtifacts(DryRun=opts.DryRun);
            case "sorting";   obj.runSorting(DryRun=opts.DryRun || c.Sorting.DryRun);
            case "signals";   obj.runSignals(DryRun=opts.DryRun);
            case "spikes";    obj.runSpikeDetection(DryRun=opts.DryRun);
            case "export";    obj.runExport(DryRun=opts.DryRun);
        end
    catch ME
        if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
            obj.log("=== cancelled during %s after %.1f s ===", step, toc(t0));
            R = obj.Results;
            return
        end
        rethrow(ME);
    end
end
n = height(obj.Results);
obj.log("=== finished in %.1f s: %d ok, %d skipped, %d error(s), %d cancelled ===", toc(t0), ...
    nnz(ismember(obj.Results.Status, ["done" "ok" "launched" "queued" "matched (prefix)" "matched (time)" "associated" "dry run"])), ...
    nnz(startsWith(obj.Results.Status, "skipped")), nnz(startsWith(obj.Results.Status, "error")), ...
    nnz(obj.Results.Status == "cancelled"));
if n == 0; obj.log("(no results)"); end
R = obj.Results;
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
