function [Y, zf] = notchFilter(X, Fs, fNotch, zi)
%notchFilter  The software notch filter of Intan's RHD2000 files before version 3.0.
%   Y = IntanReader.notchFilter(X, FS, FNOTCH) filters each column of X
%   ([nSamples x nChan] microvolts sampled at FS Hz) with the 50 or 60 Hz
%   (FNOTCH) notch, 10 Hz wide, that Intan's READ_INTAN_RHD2000_FILE
%   applies to amplifier data recorded with the software notch on. Intan's
%   per-sample loop is the second-order IIR
%
%     y(n) = k*(x(n) - 2*cos(w)*x(n-1) + x(n-2)) + (1+d^2)*cos(w)*y(n-1) - d^2*y(n-2)
%
%   with w = 2*pi*FNOTCH/FS, d = exp(-pi*10/FS) and k = (1+d^2)/2, from
%   y(1) = x(1) and y(2) = x(2). Here it is FILTER(B, A, X, ZI) with
%   B = k*[1 -2*cos(w) 1], A = [1 -(1+d^2)*cos(w) d^2] and the initial
%   state ZI that passes the first two samples unchanged: the loop's
%   values, to rounding, in a fraction of its time (every channel in one
%   call). FILTER rounds in another order than the loop, and the poles'
%   radius d (near 1) lets the difference build up to ~1e-12 of the
%   signal's size, far below the 0.195 uV step of the recording.
%
%   [Y, ZF] = IntanReader.notchFilter(X, FS, FNOTCH, ZI) goes on from ZI,
%   the final state ZF of the samples before ([2 x nChan]), so X joins them
%   as if both were filtered in one go. ZI = [] (the default) starts as
%   Intan's loop does; ZF is then [] when X has fewer than two samples,
%   which cannot start the loop.
%
%   The filter forgets its state as d^n: notchLeadIn(FS) samples on, any
%   start gives the output of the continuous filter, to rounding.
%
%   See also IntanReader.notchLeadIn, FILTER, READ_INTAN_RHD2000_FILE_MODIFIED.

arguments
    X (:,:) double
    Fs (1,1) double {mustBePositive}
    fNotch (1,1) double {mustBePositive}
    zi double = []
end

d = exp(-pi * IntanReader.NotchBandwidth / Fs);
w = 2 * pi * fNotch / Fs;
B = (1 + d^2) / 2 * [1, -2 * cos(w), 1];
A = [1, -(1 + d^2) * cos(w), d^2];

if ~isempty(zi)
    [Y, zf] = filter(B, A, X, zi);
    return
end
Y = X;
zf = [];
if size(X, 1) < 2
    return
end
% FILTER's transposed direct form: y(1) = B(1)*x(1) + z(1) and y(2) =
% B(1)*x(2) + B(2)*x(1) + z(2) - A(2)*y(1), so this z gives y(1:2) = x(1:2)
z = [(1 - B(1)) * X(1, :); (1 - B(1)) * X(2, :) + (A(2) - B(2)) * X(1, :)];
[Y, zf] = filter(B, A, X, z);
Y(1:2, :) = X(1:2, :);                  % exactly, not to rounding
end
