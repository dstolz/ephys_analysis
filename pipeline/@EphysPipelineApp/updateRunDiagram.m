function updateRunDiagram(obj, evt)
%updateRunDiagram  Move the Run tab's diagram on with one EphysPipeline event.
%   EVT is what EphysPipeline sends its ProgressFcn (see onPipelineProgress).
%   Its step becomes the one underway and the steps of the run before it
%   are done. The step's percentage is how far it is through its datasets,
%   (index - 1 + done/total) / count, and never goes back. The results so
%   far (obj.Pipe.Results) give each step its counts. The model is kept
%   while the diagram is hidden, so ticking Show the run diagram in the
%   middle of a run shows where it is.

M = obj.RunDiagram;
if M.phase ~= "running"; return; end
key = extractBefore(evt.step + ":", ":");   % "export:chronux" -> "export"
j = find([M.steps.key] == key, 1);
if isempty(j) || ~M.steps(j).inRun; return; end

for i = 1:j - 1
    if M.steps(i).inRun && ismember(M.steps(i).state, ["queued" "running"])
        M.steps(i).state = "done";
        M.steps(i).pct = 100;
    end
end

frac = 0;
if evt.total > 0; frac = min(max(evt.done / evt.total, 0), 1); end
if evt.count > 0
    frac = (max(evt.index, 1) - 1 + frac) / evt.count;   % index 0: the step is starting
end
s = M.steps(j);
s.state = "running";
s.pct = max(s.pct, 100 * min(max(frac, 0), 1));
s.index = evt.index;
s.count = evt.count;
s.dataset = evt.dataset;
s.message = evt.message;
M.steps(j) = s;
if ~isempty(obj.Pipe); M.results = obj.Pipe.Results; end
obj.RunDiagram = M;
obj.refreshRunDiagram();
end
