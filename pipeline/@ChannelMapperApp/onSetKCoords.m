function onSetKCoords(obj, how)
%onSetKCoords  The kcoords buttons: "set" the listed sites' group, "shanks" or "one" group.
%   Set takes the Sites field (site numbers and ranges, e.g. 1-16, 33:48;
%   shift-clicking a site on the probe adds it), else the selected site,
%   and gives them the group in the Group field.
try
    switch string(how)
        case "set"
            txt = strip(string(obj.KCoordSitesField.Value));
            if txt ~= ""
                sites = ChannelMapperApp.parseChannelList(txt);
            elseif isfinite(obj.Selection.site)
                sites = obj.Selection.site;
            else
                obj.setStatus('List the sites (e.g. 1-16), shift-click them on the probe, or select one first.', true);
                return
            end
            g = obj.KCoordGroupField.Value;
            obj.setKCoords(sites, g);
            obj.setStatus(sprintf('kcoords %g for %d site(s).', g, numel(unique(sites))), false);
        case "shanks"
            obj.resetKCoords();
            obj.setStatus('kcoords follow the shanks again.', false);
        case "one"
            obj.setKCoords("all", obj.KCoordGroupField.Value);
            obj.setStatus(sprintf('Every site in kcoords group %g.', obj.KCoordGroupField.Value), false);
    end
catch ME
    obj.setStatus(ME.message, true);
end
end
