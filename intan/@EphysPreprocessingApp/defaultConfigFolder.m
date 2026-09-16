function p = defaultConfigFolder(~)
    % Repository config folder: intan/ks4_configs.
    here = fileparts(mfilename('fullpath'));
    p = fullfile(fileparts(here), 'ks4_configs');
end
