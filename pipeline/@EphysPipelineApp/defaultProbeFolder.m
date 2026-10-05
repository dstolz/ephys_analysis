function p = defaultProbeFolder(~)
    % Repository probe folder: pipeline/probes (next to this @-folder).
    here = fileparts(mfilename('fullpath'));        % .../@EphysPreprocessingApp
    p = fullfile(fileparts(here), 'probes');         % .../pipeline/probes
end
