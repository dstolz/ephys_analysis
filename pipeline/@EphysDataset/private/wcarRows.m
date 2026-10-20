function X = wcarRows(obj, st, a, nWant)
%wcarRows  Samples a+1..a+nWant of the recording, weighted-CAR referenced.
%   X = wcarRows(DS, ST, A, NWANT) returns [n x nChannels] double
%   microvolts, n = NWANT or what is left of the recording after the
%   0-based sample A: every channel minus its own Kalman-tracked share of
%   the plain CAR over ST.channels (weightedCAR), as one run over the whole
%   recording gives it. The filter starts from the checkpoint of ST
%   (prepareWCAR) at or before A and runs to the last sample asked for;
%   the read is padded by ST.pad samples on both sides (clipped to the
%   recording) for the zero-phase high-pass of the estimation inputs.
%   readChunkUV and readWindowUV call it for ArtifactConfig.Reference
%   "wcar".
%
%   See also EphysDataset.prepareWCAR, weightedCAR.

N = st.nSamples;
nCh = st.nChannels;
if ~(a >= 0 && a == round(a))
    error('EphysDataset:readWindowUV:BadOffset', 'The sample offset must be a whole number of 0 or more.');
end
n = max(0, min(nWant, N - a));
if n == 0
    X = zeros(0, nCh);
    return
end
k = floor(a / st.grid);
t0 = k * st.grid;                                % the checkpoint's sample
t1 = a + n;                                      % 0-based, exclusive
r0 = max(0, t0 - st.pad);
r1 = min(N, t1 + st.pad);
R = obj.Reader.readWindowUV(r0, r1 - r0);        % as recorded, all channels
if size(R, 1) ~= r1 - r0 || size(R, 2) ~= nCh
    error('EphysDataset:readWindowUV:WCARShortRead', ...
        ['%s returned %d x %d for samples %d-%d; its weighted CAR state is for %d channel(s) ' ...
         'and %d samples (prepareWCAR(Refresh=true) works it out again).'], obj.Name, ...
        size(R, 1), size(R, 2), r0 + 1, r1, nCh, N);
end
o = st.options;
init = struct('P', st.P(:, :, k + 1), 'W', st.W(:, :, k + 1), 'NLag', st.NLag(:, k + 1));
R = weightedCAR(R, mean(R(:, st.channels), 2), 'Order', o.Order, 'Alpha1k', o.Alpha1k, ...
    'DriftPerSec', o.DriftPerSec, 'HighpassHz', o.HighpassHz, 'Estimate', o.Estimate, ...
    'Fs', st.Fs, 'Q', st.Q, 'Rows', [t0 - r0 + 1, t1 - r0], 'Initial', init);   % in place
X = R(a - r0 + 1 : t1 - r0, :);
end
