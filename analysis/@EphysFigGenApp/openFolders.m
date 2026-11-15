function openFolders(obj, folders)
%openFolders  Show the datasets in output FOLDERS: the config's source in "folders" mode, its figures as they are.
%   File > Open from database... calls it with the output folders of the
%   recordings picked (LabLocatorDialog). The config's figures and
%   defaults stay; its source becomes Mode "folders" with Folders = FOLDERS
%   (its Data tab filter kept), so the config is unsaved (Save writes the
%   new source to its file). The datasets are scanned.
arguments
    obj (1,1) EphysFigGenApp
    folders (1,:) string
end
folders = folders(strlength(folders) > 0);
if isempty(folders); return; end
cfg = obj.gatherConfig();
cfg.Source.Mode = "folders";
cfg.Source.Folders = folders;
obj.applyConfig(cfg);
scanOpened(obj);
obj.updateTitle();
obj.setStatus(sprintf('Opened %d output folder(s) from the lab database. The config''s source is now these folders (unsaved).', ...
    numel(folders)) + " " + string(obj.StatusBar.Text));
end
