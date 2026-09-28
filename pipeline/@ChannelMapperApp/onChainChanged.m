function onChainChanged(obj, what)
%onChainChanged  The probe, package or headstage changed: fill in the rest, re-mate, resolve.
%   A probe brings its defaultPackage (or a package with its channel
%   count). A package whose channel count the headstages do not match
%   brings the headstage it was verified with, else the first with its
%   channel count, else two of a headstage with half of it. The mates are
%   then the default ones (reference; ChannelMap.defaultMates) and each
%   headstage instance gets a channel offset past the one before.
b = obj.Bank;
if what == "probe" && obj.ProbeId ~= "" && b.has(obj.ProbeId)
    pr = b.get(obj.ProbeId);
    if pr.DefaultPackage ~= "" && b.has(pr.DefaultPackage)
        obj.PackageId = pr.DefaultPackage;
    elseif obj.PackageId == "" || ~b.has(obj.PackageId) || b.get(obj.PackageId).Channels ~= pr.Channels
        K = b.list("package", Channels=pr.Channels);
        if ~isempty(K)
            obj.PackageId = K(1).Id;
        end
    end
end

if what == "package" && obj.PackageId ~= "" && b.has(obj.PackageId) && obj.ProbeId ~= "" && b.has(obj.ProbeId) && ...
        b.get(obj.ProbeId).Channels ~= b.get(obj.PackageId).Channels
    % the probe design no longer fits: take one made for this package, else none
    P = b.list("probe", Channels=b.get(obj.PackageId).Channels);
    hit = P(strsOf(P, 'DefaultPackage') == obj.PackageId);
    obj.ProbeId = "";
    if ~isempty(hit)
        obj.ProbeId = hit(1).Id;
    end
end

if any(what == ["probe" "package"]) && obj.PackageId ~= "" && b.has(obj.PackageId)
    pkg = b.get(obj.PackageId);
    total = NaN;
    if obj.HeadstageId ~= "" && b.has(obj.HeadstageId)
        total = b.get(obj.HeadstageId).Channels * obj.HeadstageCount;
    end
    if total ~= pkg.Channels
        pick = "";
        count = 1;
        for v = pkg.VerifiedHeadstages(:)'
            if b.has(v)
                pick = v;
                break
            end
        end
        if pick == ""
            H = b.list("headstage", Channels=pkg.Channels);
            if ~isempty(H)
                pick = H(1).Id;
            else
                H = b.list("headstage", Channels=pkg.Channels / 2);
                if ~isempty(H)
                    pick = H(1).Id;
                    count = 2;
                end
            end
        end
        if pick ~= ""
            obj.HeadstageId = pick;
            obj.HeadstageCount = count;
        end
    end
end

obj.defaultMatesNow();
obj.fillCascade();
obj.refreshMatesTable();
obj.resolve();
obj.updateTitle();
end
