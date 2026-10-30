function rec = recordingChannels(info, nCol)
%recordingChannels  1-based amplifier channel of each extract column.
%   REC = recordingChannels(INFO, NCOL) with INFO the extract's info (toMat)
%   and NCOL its signal's column count: column c is
%   keepAmpChannels(channelRemap(c)), deriveSignals' order of operations;
%   without either option (or when they do not fit NCOL) it is channel c.
%   REC is [NCOL x 1].
%
%   See also EphysDataset.deriveSignals, selectChannels.
rec = (1:nCol).';
if ~isfield(info, 'importOptions') || ~isstruct(info.importOptions); return; end
o = info.importOptions;
k = []; r = [];
if isfield(o, 'keepAmpChannels'); k = double(o.keepAmpChannels(:)); end
if isfield(o, 'channelRemap');    r = double(o.channelRemap(:)); end
if isempty(k); k = (1:max([nCol; r])).'; end
if isempty(r); r = (1:numel(k)).'; end
if numel(r) == nCol && all(r >= 1 & r <= numel(k))
    rec = k(r);
end
end
