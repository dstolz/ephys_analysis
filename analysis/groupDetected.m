function G = groupDetected(D, opts)
%groupDetected  Which detection channels hold the spikes of one neuron.
%   G = groupDetected(D) takes the Spikes step's detected struct D (ts, info,
%   channels) and joins the channels of neighboring sites whose events behave
%   as one spike train: the spikes of one neuron that landed on different
%   sites, because the deepest site changes from spike to spike. The Spikes
%   step keeps a spike once (Coincidence "remove" or "tag", spikes within its
%   jitter on sites within its radius are copies of one) but cannot say which
%   channel a neuron belongs to.
%
%   The test is the refractory period. Two trains of one neuron, cut in two
%   by the site that won, hold no pair of events closer than the neuron's
%   refractory period, however busy they are. For each pair of neighboring
%   sites the events of one that follow an event of the other by more than
%   the Coincidence jitter (shorter lags were taken out by the step) and at
%   most RefractoryMs are counted, and compared with the count that lags
%   FlankMs from the event would give for the same width (the flank: the
%   rates, not the neuron, set it). Two neurons fire close together by
%   chance at the flank's rate. The pair is joined when
%     expected >= MinExpected     enough events to see a gap
%     observed <= MaxRatio * expected
%     poisscdf(observed, expected) <= Alpha
%   Joined pairs make a graph; its connected components are the groups.
%   Channels that are no one's neighbor, or too sparse to test, stay alone.
%
%   A group's channel is the one whose events have the largest mean |amplitude|
%   (D.info.amplitude, the trough's: the largest waveform); its spikes are the
%   events of all the group's channels, each once. With the tags of
%   Coincidence "tag" (info.primary), the copies are left out first, for every
%   channel.
%
%   Options
%     Positions       [nChan x 2] site x, y in um, NaN off the probe
%                     (default: D.info.coincidence.positions)
%     RadiusUm        sites this close on the probe are neighbors (50)
%     RefractoryMs    longest lag counted in the gap (1.5)
%     FlankMs         [from to] ms, the lags that give the expected count ([5 30])
%     MinExpected     fewest expected events in the gap to test a pair (20)
%     MaxRatio        largest observed / expected of a joined pair (0.25)
%     Alpha           largest Poisson p of a joined pair (0.001)
%
%   G fields
%     group       [nChan x 1] group number of each channel
%     members     {nGroups x 1} channel positions (in D.channels) of each group
%     best        [nGroups x 1] each group's channel position (its largest)
%     times       {nGroups x 1} the group's spike times, s, ascending
%     pairs       table, one row per tested pair: A, B (channel positions), nA, nB,
%                 observed, expected, ratio, p and joined
%     keep        {nChan x 1} logical per event of D.ts: the events used (the
%                 primaries with tags, else all)
%     jitterMs    the Coincidence jitter of the file
%
%   Errors: groupDetected:NoCoincidence (the file's Coincidence was "none", or
%   it predates it: copies of a spike sit on several channels, and no gap
%   can be told from them), groupDetected:NoPositions, groupDetected:BadDetected,
%   groupDetected:NoToolbox (the Poisson p needs the Statistics and Machine
%   Learning Toolbox).
%
%   See also selectUnits, siteNeighbors, EphysDataset.detectSpikes.

arguments
    D (1,1) struct
    opts.Positions = []
    opts.RadiusUm (1,1) double {mustBeNonnegative} = 50
    opts.RefractoryMs (1,1) double {mustBePositive} = 1.5
    opts.FlankMs (1,2) double {mustBeNonnegative} = [5 30]
    opts.MinExpected (1,1) double {mustBeNonnegative} = 20
    opts.MaxRatio (1,1) double {mustBeNonnegative} = 0.25
    opts.Alpha (1,1) double {mustBeNonnegative} = 0.001
end

if ~license('test', 'Statistics_Toolbox') || exist('poisscdf', 'file') == 0
    error('groupDetected:NoToolbox', 'groupDetected needs the Statistics and Machine Learning Toolbox (poisscdf).');
end
if ~all(isfield(D, {'ts', 'info', 'channels'})) || ~isstruct(D.info) || ~isfield(D.info, 'fs')
    error('groupDetected:BadDetected', 'The detected spikes need ts, channels and info.fs.');
end
C = struct();
if isfield(D.info, 'coincidence') && isstruct(D.info.coincidence); C = D.info.coincidence; end
if ~isfield(C, 'mode') || ~ismember(string(C.mode), ["remove" "tag"]) || ~isfield(C, 'jitterSamples')
    mode = "missing";
    if isfield(C, 'mode'); mode = string(C.mode); end
    error('groupDetected:NoCoincidence', ...
        ['The spikes file has no Coincidence handling (mode %s): a spike seen on several sites is in it more than once, ' ...
         'so the channels'' trains cannot be told apart. Run the Spikes step with Coincidence "remove" or "tag".'], mode);
end
fs = double(D.info.fs);
jit = double(C.jitterSamples);
nChan = numel(D.ts);

pos = opts.Positions;
if isempty(pos) && isfield(C, 'positions'); pos = C.positions; end
if isempty(pos) || size(pos, 1) ~= nChan || size(pos, 2) ~= 2
    error('groupDetected:NoPositions', 'The %d channels need their sites on the probe: pass Positions [nChan x 2].', nChan);
end
[~, nb] = siteNeighbors(double(pos), opts.RadiusUm);

% --- the events used, as sample numbers -------------------------------------------
keep = cell(nChan, 1);
smp = cell(nChan, 1);
for c = 1:nChan
    t = double(D.ts{c}(:));
    k = true(numel(t), 1);
    if isfield(D.info, 'primary') && numel(D.info.primary) >= c && numel(D.info.primary{c}) == numel(t)
        k = logical(D.info.primary{c}(:));
    end
    keep{c} = k;
    smp{c} = round(t(k) * fs);
end

% --- the gap test of each pair of neighboring sites ---------------------------------
gap = round(opts.RefractoryMs * fs / 1000);
flank = round(opts.FlankMs * fs / 1000);
gapWidth = gap - jit;
flankWidth = flank(2) - flank(1);
[ia, ib] = find(triu(nb, 1));
nP = numel(ia);
nA = zeros(nP, 1); nB = zeros(nP, 1);
observed = zeros(nP, 1); expected = zeros(nP, 1);
for p = 1:nP
    a = smp{ia(p)}; b = smp{ib(p)};
    nA(p) = numel(a); nB(p) = numel(b);
    if isempty(a) || isempty(b); continue; end
    lag = abs(pairLags(a, b, flank(2)));
    observed(p) = nnz(lag > jit & lag <= gap);
    expected(p) = nnz(lag > flank(1) & lag <= flank(2)) * gapWidth / flankWidth;
end
ratio = observed ./ expected;
pv = ones(nP, 1);
tested = expected >= opts.MinExpected & expected > 0;
if any(tested)
    pv(tested) = poisscdf(observed(tested), expected(tested));
end
joined = tested & ratio <= opts.MaxRatio & pv <= opts.Alpha;
G = struct();
G.pairs = table(ia, ib, nA, nB, observed, expected, ratio, pv, joined, ...
    'VariableNames', {'A', 'B', 'nA', 'nB', 'observed', 'expected', 'ratio', 'p', 'joined'});

% --- groups: the components of the joined pairs ------------------------------------
if any(joined)
    grp = conncomp(graph(ia(joined), ib(joined), [], nChan)).';
else
    grp = (1:nChan).';
end
nG = max(grp);
members = cell(nG, 1);
best = zeros(nG, 1);
times = cell(nG, 1);
meanAmp = zeros(nChan, 1);
for c = 1:nChan
    if isfield(D.info, 'amplitude') && numel(D.info.amplitude) >= c && ~isempty(D.info.amplitude{c})
        a = abs(double(D.info.amplitude{c}(:)));
        a = a(keep{c}(1:min(end, numel(a))));
        if ~isempty(a); meanAmp(c) = mean(a, 'omitnan'); end
    end
end
for g = 1:nG
    m = find(grp == g).';
    [~, o] = max(meanAmp(m));              % a tie: the lower channel
    members{g} = m;
    best(g) = m(o);
    t = cellfun(@(c) double(D.ts{c}(keep{c})), num2cell(m), 'UniformOutput', false);
    times{g} = sort(vertcat(t{:}));
end
G.group = grp;
G.members = members;
G.best = best;
G.times = times;
G.keep = keep;
G.jitterMs = 1000 * jit / fs;
end


function lag = pairLags(a, b, maxLag)
%pairLags  b - a for every pair of events at most MAXLAG samples apart (A, B sorted sample numbers).
a = a(:); b = unique(b(:));
edges = [-Inf; b; Inf];
first = discretize(a - maxLag - 1, edges);   % the first b not earlier than a - maxLag
n = discretize(a + maxLag, edges) - first;    % how many b lie within maxLag of each a
total = sum(n);
if total == 0; lag = zeros(0, 1); return; end
who = repelem((1:numel(a)).', n);
start = cumsum([0; n(1:end-1)]);
j = first(who) + (1:total).' - start(who) - 1;
lag = b(j) - a(who);
end
