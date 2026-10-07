function setKCoords(obj, sites, group)
%setKCoords  Put sites in a Kilosort4 kcoords group (no dialogs).
%   APP.setKCoords(SITES, GROUP) gives the probe design's sites SITES (site
%   numbers, or "all") the kcoords GROUP, a whole number from 0. GROUP may
%   also hold one value per site. The other sites keep theirs. When every
%   site ends up in its shank's group again, the window goes back to the
%   shanks (resetKCoords). Errors ChannelMapperApp:NoProbe (no probe
%   design), ChannelMapperApp:BadSite (a site the design does not have),
%   ChannelMapperApp:BadKCoords.
arguments
    obj
    sites
    group double
end
R = obj.Result;
if obj.ProbeId == "" || isempty(R) || all(isnan(R.Table.X))
    error('ChannelMapperApp:NoProbe', 'Choose a probe design first: kcoords group its sites.');
end
T = R.Table;
if (isstring(sites) || ischar(sites)) && string(sites) == "all"
    sites = T.Site;
end
sites = double(sites(:));
missing = sites(~ismember(sites, T.Site));
if ~isempty(missing)
    error('ChannelMapperApp:BadSite', 'The probe design has no site %s.', strjoin(compose("%g", missing'), ", "));
end
group = group(:);
if ~(isscalar(group) || numel(group) == numel(sites))
    error('ChannelMapperApp:BadKCoords', 'Give one kcoords group, or one per site.');
end
p = ChannelMap.kcoordsProblem(group);
if p ~= ""
    error('ChannelMapperApp:BadKCoords', '%s', p);
end
k = T.KCoord;
[~, at] = ismember(sites, T.Site);
k(at) = group;
if isequal(k, T.Shank)
    obj.KCoords = zeros(0, 1);
    obj.KCoordsFor = "";
else
    obj.KCoords = k;
    obj.KCoordsFor = obj.ProbeId;
end
obj.resolve();
end
