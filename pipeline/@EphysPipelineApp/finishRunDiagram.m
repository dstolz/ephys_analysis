function finishRunDiagram(obj, R, outcome, note)
%finishRunDiagram  Close the Run tab's diagram when a run ends.
%   app.finishRunDiagram(R, OUTCOME, NOTE): R is the run's Results table,
%   OUTCOME "done", "canceled" or "error", NOTE the error message.
%     done       every step of the run is done
%     canceled  the step the cancel stopped is "canceled" at the percentage
%                it reached: the one that recorded "canceled" rows, or else
%                the one underway. The steps after it are "not run".
%     error      the step underway is "failed", the steps after it "not run"
%                (an error before any step, such as an invalid plan, leaves
%                them all "not run").
%   The drawing then stays until the next run starts (resetRunDiagram).

if nargin < 4; note = ""; end
M = obj.RunDiagram;
if M.phase ~= "running"; return; end

keys = [M.steps.key];
hit = strings(1, 0);   % steps that recorded "canceled" rows
if outcome == "canceled" && ~isempty(R)
    hit = unique(extractBefore(R.Step(R.Status == "canceled") + ":", ":")).';
end
for i = find([M.steps.inRun])
    s = M.steps(i);
    if outcome == "done"
        s.state = "done";
    elseif ismember(s.key, hit)
        s.state = "canceled";
    elseif s.state == "running"
        later = keys(i + 1:end);
        if outcome == "error"
            s.state = "failed";
        elseif any(ismember(later, hit))   % finished; the cancel landed in a later step
            s.state = "done";
        else
            s.state = "canceled";
        end
    elseif s.state == "queued"
        s.state = "notrun";
    end
    if s.state == "done"; s.pct = 100; end
    M.steps(i) = s;
end

M.phase = string(outcome);
M.finished = datetime('now');
M.note = string(note);
if ~isempty(R); M.results = R; end
obj.RunDiagram = M;
obj.refreshRunDiagram();
end
