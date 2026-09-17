function v = parseFreqList(txt, what)
%parseFreqList  "60, 120 180" -> [60 120 180]. Positive finite numbers only;
%   anything unparseable is an error (EphysPipelineConfig:SignalsFreqList).
arguments
    txt = ""
    what (1,1) string = "Frequency list"
end
v = double.empty(1, 0);
if isnumeric(txt)
    v = reshape(double(txt), 1, []);
    if any(~(isfinite(v) & v > 0))
        error('EphysPipelineConfig:SignalsFreqList', '%s: frequencies must be positive and finite.', what);
    end
    return
end
t = strtrim(char(string(txt)));
if isempty(t); return; end
toks = regexp(t, '[,;\s]+', 'split');
toks = toks(~cellfun(@isempty, toks));
v = str2double(toks);
badTok = toks(~(isfinite(v) & v > 0));
if ~isempty(badTok)
    error('EphysPipelineConfig:SignalsFreqList', ...
        '%s: cannot parse "%s". Use positive frequencies in Hz, e.g. 60, 120, 180.', ...
        what, strjoin(badTok, '", "'));
end
end
