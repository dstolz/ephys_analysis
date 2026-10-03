function q = provenanceForJson(p)
%provenanceForJson  ephysProvenance's struct, ready to write into a JSON file.
%   Q = provenanceForJson(P) writes non-finite numbers in P (and in its
%   config) as the strings "Inf" / "-Inf" / "NaN", as a config file holds
%   them, so the config survives jsonencode; an empty config becomes [].
%
%   See also ephysProvenance, stringifyNonFinite.

arguments
    p (1,1) struct
end
q = p;
if isfield(q, 'config') && isempty(q.config)
    q.config = [];
end
q = stringifyNonFinite(q);
end
