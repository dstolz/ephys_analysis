function [events, D, failed] = deriveEvents(events, trials, defs, opts)
%deriveEvents  New digital-line events: a line's intervals in the trials that meet conditions.
%   [EVENTS, D, FAILED] = deriveEvents(EVENTS, TRIALS, DEFS, TrialLine=) adds one
%   line to the events struct EVENTS (line -> [k x 2] [t_on t_off] s,
%   polarity applied) for each derived-event definition in DEFS, and
%   returns the definitions with their results in D. TRIALS is the behavior
%   trials table with the pairing columns (TrialOnset, TrialOffset; see
%   pairEpsychTrials) and the trial parameters the conditions use.
%
%   A definition (EphysPipelineConfig.defaults("DerivedEvent"), the
%   Behavior.DerivedEvents entries of a pipeline config) has
%     Name        the new line's name, a valid MATLAB identifier that is not
%                 a line yet ("Trial", the trial line, a recorded line or an
%                 earlier derived event)
%     Line        the line whose intervals are taken: any line of EVENTS
%                 ("Trial" = the trial line, TrialLine), including a derived
%                 event defined before this one
%     Conditions  one or more logical expressions over the trial columns, in
%                 the trial-filter language (see trialSelection:
%                 "Depth >= -6", "Depth < -6 & Depth >= -10", "Hit | FA",
%                 ismember(Level, [40 60]), ...); never passed to eval
%     Combine     "all" (default): a trial must meet every condition; "any":
%                 at least one
%     InDataset   also put the line in the extract's events and a logical
%                 trials column named Name in the behavior file (used by the
%                 callers; deriveEvents only checks that no trial column has
%                 that name yet)
%   The definitions are taken in order, so one can build on an earlier one.
%
%   An interval of Line belongs to the paired trial whose [TrialOnset,
%   TrialOffset] holds its onset (the first such trial); it is kept when
%   that trial meets the conditions. Intervals outside every paired trial
%   are dropped.
%
%   D has one element per definition made (1 x 0 without any):
%     index        the definition's place in DEFS
%     name, line, conditions, combine, inDataset   the definition as given
%     sourceLine   the line the intervals came from ("Trial" resolved)
%     expression   the conditions as one expression ("(a) & (b)")
%     description  "<line> intervals of the trials where <expression>"
%     trials       [nTrials x 1] logical: the trial meets the conditions
%                  (paired or not)
%     nTrials      paired trials that meet them
%     intervals    [k x 2] s, the new line's intervals
%     nIntervals   k
%
%   Options
%     TrialLine   the line "Trial" stands for (the pairing's trial line)
%     OnError     "error" (default): a definition that cannot be made is an
%                 error; "skip": it is left out of EVENTS and D, and FAILED
%                 says why (a session without a parameter a condition uses,
%                 when one config serves many sessions)
%   FAILED is a struct array (index, name, identifier, message), 1 x 0 when
%   every definition was made.
%
%   Errors: deriveEvents:NoTrials (definitions without paired trials),
%   deriveEvents:BadName, deriveEvents:NoLine, deriveEvents:BadCondition.
%
%   See also EphysDataset.behaviorStruct, tableFilterFcn, pairEpsychTrials.

arguments
    events (1,1) struct
    trials table
    defs = []
    opts.TrialLine (1,1) string = ""
    opts.OnError (1,1) string {mustBeMember(opts.OnError, ["error" "skip"])} = "error"
end

D = repmat(struct('index', 0, 'name', "", 'line', "", 'conditions', string.empty(1, 0), 'combine', "all", ...
    'inDataset', false, 'sourceLine', "", 'expression', "", 'description', "", ...
    'trials', false(0, 1), 'nTrials', 0, 'intervals', zeros(0, 2), 'nIntervals', 0), 1, 0);
failed = repmat(struct('index', 0, 'name', "", 'identifier', "", 'message', ""), 1, 0);
defs = normalizeDefs(defs);
if isempty(defs)
    return
end
vars = string(trials.Properties.VariableNames);
if ~all(ismember(["TrialOnset" "TrialOffset"], vars))
    error('deriveEvents:NoTrials', ...
        'Derived events need paired trials (TrialOnset / TrialOffset): pair the trials with the trial line first.');
end
T = textToString(trials);
on = double(T.TrialOnset);
off = double(T.TrialOffset);
paired = isfinite(on) & isfinite(off);
rf = "RespCode";
if ~ismember(rf, vars) && ismember("ResponseCode", vars); rf = "ResponseCode"; end

for k = 1:numel(defs)
    try
        [events, Dk] = oneEvent(events, T, vars, rf, on, off, paired, defs(k), k, opts.TrialLine);
        D(end+1) = Dk; %#ok<AGROW>
    catch ME
        if opts.OnError == "error"; rethrow(ME); end
        failed(end+1) = struct('index', k, 'name', strtrim(defs(k).Name), ...
            'identifier', string(ME.identifier), 'message', string(ME.message)); %#ok<AGROW>
    end
end
end


function [events, Dk] = oneEvent(events, T, vars, rf, on, off, paired, def, k, trialLine)
%oneEvent  Make one derived event; errors say what is wrong with its definition.
name = strtrim(def.Name);
if ~isvarname(name)
    error('deriveEvents:BadName', ...
        'Derived event %d: "%s" is not a valid name (letters, digits and _, starting with a letter).', k, name);
end
if name == "Trial" || name == trialLine || isfield(events, name)
    error('deriveEvents:BadName', 'Derived event "%s": a line of that name already exists.', name);
end
if def.InDataset && ismember(name, vars)
    error('deriveEvents:BadName', ...
        'Derived event "%s": the trials already have a column of that name (its InDataset column would replace it).', name);
end
line = strtrim(def.Line);
src = line;
if line == "Trial"
    src = trialLine;
end
if src == "" || ~isfield(events, src)
    error('deriveEvents:NoLine', 'Derived event "%s": no line "%s" (lines: %s).', ...
        name, line, strjoin(string(fieldnames(events)), ", "));
end
conds = strtrim(def.Conditions);
conds = conds(conds ~= "");
if isempty(conds)
    error('deriveEvents:BadCondition', 'Derived event "%s" has no condition.', name);
end
if ~ismember(def.Combine, ["all" "any"])
    error('deriveEvents:BadCondition', 'Derived event "%s": Combine must be "all" or "any" (got "%s").', name, def.Combine);
end
meets = def.Combine == "all";
for c = conds
    try
        f = tableFilterFcn(c, vars, RespField=rf);
        m = f(T);
    catch ME
        error('deriveEvents:BadCondition', 'Derived event "%s": %s', name, ME.message);
    end
    if def.Combine == "all"; meets = meets & m; else; meets = meets | m; end
end
meets = reshape(meets, [], 1) & true(height(T), 1);

iv = double(events.(src));
if isempty(iv); iv = zeros(0, 2); end
owner = containingTrial(iv(:, 1), on, off, paired);
keep = isfinite(owner);
keep(keep) = meets(owner(keep));
events.(name) = iv(keep, :);

joiner = " & ";
if def.Combine == "any"; joiner = " | "; end
expr = conds;
if numel(conds) > 1; expr = "(" + conds + ")"; end
expr = strjoin(expr, joiner);
Dk = struct('index', k, 'name', name, 'line', line, 'conditions', conds, 'combine', def.Combine, ...
    'inDataset', logical(def.InDataset), 'sourceLine', src, 'expression', expr, ...
    'description', line + " intervals of the trials where " + expr, 'trials', meets, ...
    'nTrials', nnz(meets & paired), 'intervals', iv(keep, :), 'nIntervals', nnz(keep));
end


function defs = normalizeDefs(defs)
%normalizeDefs  Definitions as a row of complete DerivedEvent structs.
if isempty(defs)
    defs = [];
    return
end
if iscell(defs); defs = [defs{:}]; end
if ~isstruct(defs)
    error('deriveEvents:BadName', 'The derived events must be a struct array of definitions.');
end
out = cell(1, numel(defs));
for k = 1:numel(defs)
    out{k} = EphysPipelineConfig.normalizeSection("DerivedEvent", defs(k));
end
defs = [out{:}];
end


function r = containingTrial(x, on, off, paired)
%containingTrial  Row of the first paired trial whose [on off] holds each time in X (NaN: none).
r = NaN(size(x));
for j = 1:numel(x)
    k = find(paired & on <= x(j) & off >= x(j), 1);
    if ~isempty(k); r(j) = k; end
end
end


function T = textToString(T)
%textToString  cellstr / char columns as string, so conditions compare with ==.
for v = string(T.Properties.VariableNames)
    x = T.(v);
    if iscellstr(x) || ischar(x) %#ok<ISCLSTR>
        T.(v) = string(x);
    end
end
end
