function r = sourceRates(S)
%sourceRates  The signals' rates of config Source S (Source.Downsample): a field per signal, [] = the rate on file.
%   R = sourceRates(S) is S.Downsample with every signal's field
%   (DownsampleDialog.normalize), every one [] when S has no Downsample: a
%   config made in a MATLAB session that loaded EphysAnalysisConfig before
%   the field existed (a class's property defaults are evaluated once per
%   session, until clear classes) has none, and must not stop the app.
%
%   See also showDownsample, onDownsample, DownsampleDialog.normalize.
d = [];
if isstruct(S) && isfield(S, 'Downsample'); d = S.Downsample; end
r = DownsampleDialog.normalize(d);
end
