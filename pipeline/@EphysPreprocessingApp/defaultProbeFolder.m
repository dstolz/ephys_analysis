function p = defaultProbeFolder(~)
    % Repository probe folder: intan/probes (next to this @-folder).
    here = fileparts(mfilename('fullpath'));        % .../@EphysPreprocessingApp
    p = fullfile(fileparts(here), 'probes');         % .../intan/probes
end
