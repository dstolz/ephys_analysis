function [derivedFile, nExcluded] = writeExcludedProbe(probeFile, excludeCh, resultsDir, nChanBin, who)
%writeExcludedProbe  Write a probe .json with excludeCh removed from the map.
%   excludeCh are 1-based .bin channels; a probe site is kept unless its
%   chanMap value + 1 is in excludeCh. n_chan is preserved so it still matches
%   n_chan_bin. Returns the original file unchanged when nothing is dropped.
%   The probe has passed probeMapProblems; the derived one goes through
%   writeProbeMap, so a single site left is still a list Kilosort4 reads.
%   WHO names the caller in the error identifier.
derivedFile = string(probeFile);
probe = readJsonFile(probeFile);
cm = double(probe.chanMap(:));
keep = ~ismember(cm + 1, excludeCh(:));
nExcluded = nnz(~keep);
if nExcluded == 0
    return   % nothing in excludeCh is on this probe; keep the original
end
if ~any(keep)
    error(['EphysDataset:' char(who) ':AllExcluded'], ...
        'Every site of the probe %s is excluded; nothing is left to sort.', probeFile);
end

% Filter the per-site arrays in lockstep; n_chan and the other fields stay.
for f = ["chanMap" "xc" "yc" "kcoords"]
    v = probe.(f);
    probe.(f) = v(keep);
end

[~, pn] = fileparts(char(probeFile));
derivedFile = string(fullfile(char(resultsDir), pn + "_excluded.json"));
writeProbeMap(derivedFile, probe);

nKept = numel(cm) - nExcluded;
if nKept ~= nChanBin
    % Informational: the sorter sorts nKept of nChanBin channels.
    fprintf('Derived probe: %d of %d channel(s) retained for sorting.\n', ...
        nKept, nChanBin);
end
end
