function p = defaultConfigFolder(~)
%defaultConfigFolder  Repository folder for pipeline configs: pipeline/pipeline_configs.
here = fileparts(mfilename('fullpath'));
p = fullfile(fileparts(here), 'pipeline_configs');
end
