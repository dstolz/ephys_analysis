function [owner, pairs] = containingTrial(x, on, off, tol)
%containingTrial  The trial that holds each time (or interval) of X.
%   OWNER = containingTrial(X, ON, OFF, TOL) takes X [n x 1] times in
%   seconds and the trials' [ON OFF] (pairEpsychTrials' TrialOnset /
%   TrialOffset, s; one entry per trial, NaN for a trial without a partner)
%   and returns OWNER [n x 1], the row of the trial that holds each time:
%       ON(k) <= x <= OFF(k) + TOL
%   NaN where no trial holds it. A time held by two touching trials belongs
%   to the earlier one.
%
%   TOL is the one-sample asymmetry of the digital-event convention: an
%   event is placed at t = row/Fs, TrialOnset is the first high row and
%   TrialOffset the LAST high row of the trial line, so an event on the first
%   low row (TrialOffset + 1/Fs) happened right after the trial and is still
%   its own. Callers pass TOL = 1/Fs (0: the closed interval [ON OFF]).
%
%   [OWNER, PAIRS] = containingTrial(IV, ON, OFF, TOL) with IV [n x 2]
%   intervals [t_on t_off] also lists every overlap. OWNER is then the trial
%   holding the interval's onset, else (the onset lies between trials) the
%   first trial the interval overlaps. PAIRS [m x 2] holds [interval trial]
%   rows for every trial an interval overlaps (IV(:,1) <= OFF + TOL and
%   IV(:,2) >= ON), sorted by trial, then interval, so
%   IV(PAIRS(PAIRS(:,2) == k, 1), :) are the intervals "in" trial k, which is
%   what pairEpsychTrials keeps as TrialEvents. The rule for the 1-column
%   form and the onset of the 2-column form is the same.
%
%   Vectorized: a binary search over the sorted trial onsets for every time
%   at once (discretize), then the offset test, so n times and k trials cost
%   O((n + k) log k) and not n * k. Trials with a NaN onset or offset are left
%   out. Assumptions: the trials do not overlap each other apart from
%   touching (they are the intervals of one line paired in order), so only
%   the trial starting last at or before a time, and the one before it, can
%   hold it; trials with equal onsets are one trial (the first row wins).
%
%   See also pairEpsychTrials, resolveEvents, deriveEvents.

arguments
    x double
    on (:,1) double
    off (:,1) double
    tol (1,1) double {mustBeNonnegative, mustBeFinite} = 0
end
if size(x, 2) > 2 || (size(x, 2) == 0 && ~isempty(x))
    error('containingTrial:Shape', 'X must be [n x 1] times or [n x 2] intervals.');
end
if numel(on) ~= numel(off)
    error('containingTrial:Shape', 'ON and OFF must have one entry per trial.');
end

n = size(x, 1);
owner = NaN(n, 1);
pairs = zeros(0, 2);
good = find(isfinite(on) & isfinite(off));
if n == 0 || isempty(good)
    return
end
[onS, ord] = sort(on(good));        % trials in time order
rowS = good(ord);                   % their rows
offS = off(rowS);

% --- the trial holding each time: the last onset at or before it, or the one before ---
[uOn, first] = unique(onS, 'first');
k = discretize(x(:, 1), [uOn; Inf]);         % uOn(k) <= x < uOn(k+1); NaN before the first trial
has = ~isnan(k);
cur = NaN(n, 1);
cur(has) = first(k(has));                    % position (in time order) of that trial
prev = NaN(n, 1);
sel = has & k >= 2;
prev(sel) = first(k(sel) - 1);               % ... and of the trial before it
pos = NaN(n, 1);
usePrev = false(n, 1);
usePrev(sel) = x(sel, 1) <= offS(prev(sel)) + tol;   % touching trials: the earlier one
pos(usePrev) = prev(usePrev);
useCur = has & ~usePrev;
useCur(useCur) = x(useCur, 1) <= offS(cur(useCur)) + tol;
pos(useCur) = cur(useCur);
held = isfinite(pos);
owner(held) = rowS(pos(held));

if size(x, 2) < 2
    return
end

% --- every overlap of an interval [a b] with a trial ---------------------------------
a = x(:, 1);
b = x(:, 2);
reach = cummax(offS) + tol;                  % how far the trials up to each one reach
f = countRel(reach, a, false) + 1;           % first trial (time order) reaching a
l = countRel(onS, b, true);                  % last trial starting at or before b
cnt = max(l - f + 1, 0);
cnt(isnan(cnt)) = 0;
j = find(cnt > 0);
if isempty(j)
    return
end
c = cnt(j);
tot = sum(c);
ivIdx = repelem(j, c);
ivIdx = ivIdx(:);                            % repelem of a scalar is a row
posS = repelem(f(j), c);
posS = posS(:) + (1:tot).' - reshape(repelem(cumsum(c) - c, c), [], 1) - 1;
keep = offS(posS) + tol >= a(ivIdx);         % trials whose own end reaches a (offsets need not rise)
ivIdx = ivIdx(keep);
posS = posS(keep);
tr = rowS(posS);
[~, o] = sortrows([tr ivIdx]);
pairs = [ivIdx(o) tr(o)];

% an onset between trials: the first trial the interval overlaps
firstPos = accumarray(ivIdx, posS, [n 1], @min, NaN);
between = isnan(owner) & isfinite(firstPos);
owner(between) = rowS(firstPos(between));
end


function c = countRel(s, v, inclusive)
%countRel  How many elements of the sorted S are below (or, INCLUSIVE, at or below) each V.
s = s(:);
[u, ~, ic] = unique(s);
cum = cumsum(accumarray(ic, 1));             % cum(i) elements of S are <= u(i)
k = discretize(v, [u; Inf]);                 % u(k) <= v
c = zeros(size(v));
has = ~isnan(k);
c(has) = cum(k(has));
if ~inclusive
    atV = false(size(v));
    atV(has) = u(k(has)) == v(has);          % the ties with V do not count as below it
    below = [0; cum(1:end - 1)];
    c(atV) = below(k(atV));
end
c(isnan(v)) = NaN;
end
