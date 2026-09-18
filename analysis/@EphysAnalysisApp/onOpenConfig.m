function onOpenConfig(obj)
%onOpenConfig  Pick an analysis config JSON and open it.
if ~obj.confirmDiscard(); return; end
start = char(obj.Config.File);
if isempty(start) || ~isfile(start); start = char(obj.defaultConfigFolder()); end
[f, p] = uigetfile({'*.json', 'Analysis config (*.json)'}, "Open analysis config", start);
figure(obj.Fig);
if isequal(f, 0); return; end
obj.openConfigFile(fullfile(p, f));
end
