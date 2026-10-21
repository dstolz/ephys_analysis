function test_RemoveLineNoise()
%test_RemoveLineNoise  Mains interference removed by sliding sinusoid fits (removeLineNoise).
%   Checks:
%     1. a steady line (three harmonics, on and off LineHz) under faint
%        noise is removed to 55 dB over the whole record, ends included,
%        at 1 kHz, 30 kHz and TDT's 24414.0625 Hz (blocks not whole
%        samples)
%     2. a drifting line (+/- 0.05 Hz) on brown noise: the frequency track
%        follows it, tracking beats Tracking "fixed", and "global" finds a
%        steady line's frequency
%     3. channels without a line keep their signal (soft and hard gates;
%        "none" takes more), and nothing is added to them
%     4. a broadband transient on a line-free channel is not taken for
%        line; Exclude keeps it out of the fits of a channel with a line
%     5. NaN samples stay NaN, take no part, and the rest of the channel
%        is cleaned
%     6. pieces run with INFO.MarginRows and FirstRow equal one run
%        (Tracking "window" and "fixed", PerChannel, a piece starting
%        mid-block)
%     7. PerChannel: each channel's own frequency
%     8. output class and shape, INFO's sizes and times, input checks
%     9. an informational timing (minutes per 64-channel hour at 30 kHz)
%   Needs no toolbox and no data files.
%
%   Usage:  test_RemoveLineNoise

here = fileparts(mfilename('fullpath'));
addpath(here);

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end
dB = @(ref, err) 20 * log10(rms(ref) ./ rms(err));

fprintf('\n== 1. a steady line, removed to the ends ==\n');
rng(1);
rates = [1000 30000 24414.0625];
lineHz = [60 60.03 59.93];
for r = 1:3
    Fs = rates(r);
    N = round(40 * Fs);
    t = (0:N-1)' / Fs;
    s = 0.01 * randn(N, 4);
    line = zeros(N, 4);
    f = lineHz(r);
    for k = 1:3
        line = line + (10 / k) * cos(2 * pi * k * f .* t + k * (1:4));
    end
    [Y, info] = removeLineNoise(s + line, Fs=Fs);
    att = dB(line, Y - s);
    check(all(att >= 50), sprintf('%g Hz, a %g Hz line: %s dB (>= 50)', Fs, f, sprintf('%.1f ', att)));
    check(info.WindowSec > 1.99 && info.WindowSec < 2.01 && info.HopSec == info.WindowSec / 2, ...
        sprintf('%g Hz: window %.4f s of %d-sample blocks', Fs, info.WindowSec, info.BlockSamples));
end

fprintf('\n== 2. a drifting line: tracking ==\n');
rng(2);
Fs = 1000; N = 180 * Fs; nCh = 6;
t = (0:N-1)' / Fs;
fTrue = 60 + 0.05 * sin(2 * pi * t / 60);
ph = 2 * pi * cumsum(fTrue) / Fs;
neural = filter(1, [1 -0.95], randn(N, nCh));
neural = neural ./ std(neural);
amp = [20 10 5 2 1 0.5];
line = zeros(N, nCh);
for k = 1:3
    line = line + (amp / k) .* cos(k * ph + 2 * pi * rand(1, nCh));
end
X = neural + line;
[Y, info] = removeLineNoise(X, Fs=Fs);
inner = info.time > 2 & info.time < 178;
fe = abs(info.frequency(inner) - interp1(t, fTrue, info.time(inner)));
check(max(fe) < 0.005, sprintf('frequency within %.4f Hz of the drift (< 0.005)', max(fe)));
check(all(info.trusted(inner)), 'every inner window trusted');
att = dB(line, Y - neural);
check(all(att(1:3) >= 35) && all(att >= 15), sprintf('attenuation %s dB (>= 35 strong, >= 15 all)', sprintf('%.1f ', att)));
Yf = removeLineNoise(X, Fs=Fs, Tracking="fixed");
attF = dB(line, Yf - neural);
check(all(att(1:3) >= attF(1:3) + 6), sprintf('Tracking "fixed" %s dB, at least 6 dB worse', sprintf('%.1f ', attF(1:3))));
steady = neural + 5 * cos(2 * pi * 60.037 * t);
[~, ig] = removeLineNoise(steady, Fs=Fs, Tracking="global");
check(all(ig.frequency == ig.frequency(1)) && abs(ig.frequency(1) - 60.037) < 5e-4, ...
    sprintf('Tracking "global": %.4f Hz for a 60.037 Hz line', ig.frequency(1)));

fprintf('\n== 3. channels without a line ==\n');
Xq = [X neural(:, 1:2) * 3];   % two line-free channels beside six with one
for gate = ["soft" "hard" "none"]
    [Yq, iq] = removeLineNoise(Xq, Fs=Fs, Gate=gate);
    change = rms(Yq(:, 7:8) - Xq(:, 7:8)) ./ rms(Xq(:, 7:8));
    limit = 0.03 + 0.05 * (gate == "none");
    check(all(change < limit), sprintf('Gate "%s": quiet channels changed by %s of rms (< %g)', ...
        gate, sprintf('%.4f ', change), limit));
    check(all(rms(Yq(:, 7:8)) <= rms(Xq(:, 7:8))), sprintf('Gate "%s": nothing added to them', gate));
    if gate == "soft"
        soft = change;
        check(median(iq.amplitude(:, 7:8, 1), 'all') < 0.02 * median(iq.amplitude(:, 1, 1)), ...
            'their fitted amplitude is a few % of the strong channel''s');
    elseif gate == "none"
        check(all(change > soft), 'Gate "none" takes more from them than "soft"');
    end
end
[~, iq] = removeLineNoise(Xq, Fs=Fs, MinSNR=6, Gate="hard");
check(mean(iq.snr(:, 7:8, :) >= 6, 'all') < 0.1 && mean(iq.snr(:, 1:3, 1) >= 6, 'all') == 1, ...
    'hard gate: the strong channels pass every window, the quiet ones few');

fprintf('\n== 4. transients and Exclude ==\n');
rng(4);
nb = 60 * Fs;
tb = (0:nb-1)' / Fs;
quiet = filter(1, [1 -0.95], randn(nb, 1));
quiet = quiet / std(quiet);
burst = zeros(nb, 1);
r = 30 * Fs + (1:50);
burst(r) = 300 * sin(pi * (1:50)' / 50);   % a 50 ms, 300 x rms swing
lineOnly = 5 * cos(2 * pi * 60.02 * tb);
Xb = [quiet + burst, quiet + burst + lineOnly];
far = abs(tb - 30) > 1;
Ys = removeLineNoise(Xb, Fs=Fs);
Yn = removeLineNoise(Xb, Fs=Fs, Gate="none");
spreadS = rms(Ys(far, 1) - Xb(far, 1)) / rms(quiet(far));
spreadN = rms(Yn(far, 1) - Xb(far, 1)) / rms(quiet(far));
check(spreadS < 0.05 && spreadS < spreadN, sprintf( ...
    'line-free channel: %.3f of rms changed beyond 1 s of the burst (Gate "none" %.3f)', spreadS, spreadN));
ex = [r(1) - 10, r(end) + 10];
Ye = removeLineNoise(Xb, Fs=Fs, Exclude=ex);
out = true(nb, 1);
out(ex(1):ex(2)) = false;
attIn = dB(lineOnly(out), Ys(out, 2) - quiet(out) - burst(out));
attEx = dB(lineOnly(out), Ye(out, 2) - quiet(out) - burst(out));
check(attEx >= 30 && attEx > attIn, sprintf('line channel: %.1f dB with Exclude, %.1f without', attEx, attIn));

fprintf('\n== 5. NaN samples ==\n');
Xn = X;
gap = 50 * Fs + (1:3 * Fs);
Xn(gap, 2) = NaN;
[Yn, in] = removeLineNoise(Xn, Fs=Fs);
check(all(isnan(Yn(gap, 2))) && nnz(isnan(Yn)) == numel(gap), 'NaN samples stay NaN, no others appear');
keep = true(size(X, 1), 1);
keep(gap) = false;
attN = dB(line(keep, 2), Yn(keep, 2) - neural(keep, 2));
check(attN >= att(2) - 3, sprintf('the rest of that channel: %.1f dB (whole: %.1f)', attN, att(2)));
check(~all(in.fitted(:, 2)) && all(in.fitted(:, 1)), 'its windows inside the gap are not fitted');

fprintf('\n== 6. pieces ==\n');
cases = {{}, {'Tracking', "fixed"}, {'PerChannel', true}, {'WindowSec', 1, 'SmoothWindows', 3}};
for c = 1:numel(cases)
    o = [{'Fs', Fs}, cases{c}];
    [Yw, iw] = removeLineNoise(X, o{:});
    M = iw.MarginRows;
    cuts = [1, 61 * Fs + 37, 122 * Fs + 501, size(X, 1) + 1];   % off the block and window grids
    Yp = zeros(size(X));
    for p = 1:3
        a = max(1, cuts(p) - M);
        b = min(size(X, 1), cuts(p + 1) - 1 + M);
        Yc = removeLineNoise(X(a:b, :), o{:}, FirstRow=a);
        Yp(cuts(p):cuts(p + 1) - 1, :) = Yc(cuts(p) - a + 1 : cuts(p + 1) - a, :);
    end
    check(max(abs(Yp - Yw), [], 'all') < 1e-9 * max(abs(X), [], 'all'), ...
        sprintf('%s: three pieces equal one run (margin %d rows)', strjoin(string(cases{c}), " "), M));
end

fprintf('\n== 7. PerChannel ==\n');
[Yc, ic] = removeLineNoise(X, Fs=Fs, PerChannel=true);
check(isequal(size(ic.frequency), [numel(ic.time) nCh]), 'a frequency per window and channel');
fe = abs(ic.frequency(inner, 1:3) - interp1(t, fTrue, info.time(inner)));
check(max(fe, [], 'all') < 0.01, sprintf('strong channels within %.4f Hz', max(fe, [], 'all')));
attC = dB(line, Yc - neural);
check(all(attC(1:3) >= att(1:3) - 3), sprintf('attenuation %s dB', sprintf('%.1f ', attC)));
fc = [60 60.03 59.97 60.1];   % channels not recorded together: a line each
nd = 40 * Fs;
td = (0:nd-1)' / Fs;
sd = 0.01 * randn(nd, 4);
ld = 10 * cos(2 * pi * fc .* td + (1:4));
attS = dB(ld, removeLineNoise(sd + ld, Fs=Fs) - sd);
[Yd, id] = removeLineNoise(sd + ld, Fs=Fs, PerChannel=true);
attD = dB(ld, Yd - sd);
check(all(attD >= 50) && min(attS) < 30, sprintf( ...
    'a different line per channel: %s dB with PerChannel, as low as %.1f without', sprintf('%.1f ', attD), min(attS)));
check(all(abs(median(id.frequency) - fc) < 1e-3), 'and its frequencies are theirs');

fprintf('\n== 8. class, INFO, checks ==\n');
[Ys1, is1] = removeLineNoise(single(X(1:20 * Fs, :)), Fs=Fs);
check(isa(Ys1, 'single') && isequal(size(Ys1), [20 * Fs, nCh]), 'single in, single out, same size');
nWin = numel(is1.time);
check(isequal(size(is1.amplitude), [nWin nCh 3]) && isequal(size(is1.snr), [nWin nCh 3]) ...
    && isequal(size(is1.fitted), [nWin nCh]) && isequal(size(is1.frequency), [nWin 1]), 'INFO sizes');
check(is1.time(1) == 0 && all(abs(diff(is1.time) - is1.HopSec) < 1e-12) && is1.time(end) >= 20 - 1 / Fs, ...
    'window centers from 0 every HopSec, past the last row');
[~, i50] = removeLineNoise(X(1:10 * Fs, :), Fs=Fs, LineHz=50, Harmonics=[1 3 5], MaxDeviationHz=0.1);
check(isequal(i50.Harmonics, [1 3 5]) && all(abs(i50.frequency - 50) <= 0.1), 'LineHz 50, odd harmonics');
x = X(1:5 * Fs, 1);
check(strcmp(errorId(@() removeLineNoise(x)), 'removeLineNoise:Fs'), 'Fs required');
check(strcmp(errorId(@() removeLineNoise(x, Fs=Fs, Harmonics=1:9)), 'removeLineNoise:Harmonics'), ...
    'a harmonic at Nyquist refused');
check(strcmp(errorId(@() removeLineNoise(x, Fs=Fs, WindowSec=0.1)), 'removeLineNoise:WindowSec'), ...
    'a window too short refused');
check(strcmp(errorId(@() removeLineNoise(x, Fs=Fs, SmoothWindows=4)), 'removeLineNoise:SmoothWindows'), ...
    'an even SmoothWindows refused');
check(strcmp(errorId(@() removeLineNoise(x, Fs=Fs, Exclude=[10 6 * Fs])), 'removeLineNoise:Exclude'), ...
    'Exclude beyond X refused');
check(strcmp(errorId(@() removeLineNoise(ones(10, 2, 2), Fs=Fs)), 'removeLineNoise:X'), 'a 3-D X refused');
check(isequal(removeLineNoise(x, Fs=Fs, Gate="hard", MinSNR=Inf), x), 'MinSNR Inf leaves X as it was');

fprintf('\n== 9. timing (informational) ==\n');
Fs = 30000; N = 20 * Fs;
Z = single(randn(N, 64) + 5 * cos(2 * pi * 60.03 * (0:N-1)' / Fs + (1:64)));
t0 = tic; Z = removeLineNoise(Z, Fs=Fs); el = toc(t0); %#ok<NASGU>
fprintf('    %.1f min per 64-channel hour at 30 kHz (single)\n', el * 3600 / 20 / 60);

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_RemoveLineNoise:Failures', '%d checks failed.', nFail);
end
end
