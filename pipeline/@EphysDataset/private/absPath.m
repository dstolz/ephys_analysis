function p = absPath(p)
%absPath  P as an absolute, canonical path (char).
%   A relative P is taken from pwd; . and .. are resolved. runKilosort and
%   runSpikeInterface hand these to Python through system(), which wants
%   absolute, double-quoted paths.
p = char(p);
d = fileparts(p);
if isempty(d) || ~isAbsolute(d)
    p = fullfile(pwd, p);
end
% Normalize via Java file to resolve any . / .. components
try
    p = char(java.io.File(p).getCanonicalPath());
catch
    p = char(p);
end
end


function tf = isAbsolute(d)
d = char(d);
tf = ~isempty(regexp(d, '^([A-Za-z]:[\\/]|[\\/]{2}|[\\/])', 'once'));
end
