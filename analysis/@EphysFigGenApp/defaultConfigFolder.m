function p = defaultConfigFolder(~)
%defaultConfigFolder  Where analysis configs are offered by default: analysis/analysis_configs.
here = fileparts(mfilename('fullpath'));
p = fullfile(fileparts(here), 'analysis_configs');
if ~isfolder(p); p = fileparts(here); end
end
