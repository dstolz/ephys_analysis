function derivedFile = writeRecordedProbe(ds, probeFile, runDir, nChanBin)
%writeRecordedProbe  Write the probe as the recording's channels sit on it, when channels were disabled.
%   A recording with channels disabled at acquisition holds fewer .bin rows
%   than the probe has sites: EphysDataset.recordedProbe matches the sites
%   to the rows by hardware number and leaves out the sites of the channels
%   not recorded. That probe is written to <runDir>\<probe>_recorded.json
%   and returned; the probe given is returned unchanged when nothing needs
%   matching, or when the .bin does not hold the dataset's channels
%   (NCHANBIN is not its NumChannels: a .bin given as it is). The probe has
%   passed probeMapProblems; the original .json is never modified.
derivedFile = string(probeFile);
if nChanBin ~= ds.NumChannels
    return
end
[P, info] = ds.recordedProbe(probeFile);
if ~info.remapped
    return
end
[~, pn] = fileparts(char(probeFile));
derivedFile = string(fullfile(char(runDir), pn + "_recorded.json"));
writeProbeMap(derivedFile, P);
fprintf(['Channels disabled at acquisition: %d probe site(s) not recorded (probe channel(s) %s) left out; ' ...
    'the other %d sites matched to the .bin rows by hardware number.\n'], numel(info.missing), ...
    char(EphysDataset.formatChannelList(info.missing + 1)), numel(P.chanMap));
end
