function onOpenConfig(obj)
%onOpenConfig  Pick a config JSON and open it.
if ~obj.confirmDiscard(); return; end
start = char(obj.Config.File);
if isempty(start) || ~isfile(start); start = char(obj.defaultConfigFolder()); end
[f, p] = uigetfile({'*.json', 'Pipeline config (*.json)'}, "Open pipeline config", start);
figure(obj.Fig);
if isequal(f, 0); return; end
obj.openConfigFile(fullfile(p, f));
end
