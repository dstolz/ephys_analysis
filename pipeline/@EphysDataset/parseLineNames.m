function [natives, names] = parseLineNames(lineNames)
%parseLineNames  Split "native=name" line-name entries.
%   [NATIVES, NAMES] = EphysDataset.parseLineNames(["TTL4=InTrial" "TTL1 = Trough"])
%   returns the native line names and the names given to them (both 1 x n,
%   white space trimmed). Throws EphysDataset:LineNames when an entry has no
%   "=", an empty side, a name that is not a valid MATLAB identifier, or
%   when a native line or a name appears twice.
%
%   See also EphysDataset.relabelEvents, EphysPipelineConfig.validate.

arguments
    lineNames (1,:) string = string.empty(1,0)
end

n = numel(lineNames);
natives = strings(1, n);
names = strings(1, n);
for k = 1:n
    t = char(lineNames(k));
    eq = find(t == '=', 1);
    if isempty(eq)
        error('EphysDataset:LineNames', 'Line name "%s" is not of the form native=name (e.g. TTL4=InTrial).', t);
    end
    natives(k) = strtrim(string(t(1:eq-1)));
    names(k) = strtrim(string(t(eq+1:end)));
    if natives(k) == "" || names(k) == ""
        error('EphysDataset:LineNames', 'Line name "%s" needs a native line and a name (e.g. TTL4=InTrial).', t);
    end
    if ~isvarname(names(k))
        error('EphysDataset:LineNames', ...
            'Line name "%s": "%s" is not a valid name (letters, digits and _, starting with a letter).', t, names(k));
    end
end
if numel(unique(lower(natives))) < n
    error('EphysDataset:LineNames', 'A native line is named twice in the line names.');
end
if numel(unique(names)) < n
    error('EphysDataset:LineNames', 'Two native lines are given the same name.');
end
end
