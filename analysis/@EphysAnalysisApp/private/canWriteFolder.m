function tf = canWriteFolder(folder)
%canWriteFolder  True when a file can be written in FOLDER (a read-only share cannot).
%   Writes and deletes a probe file of a name no other file has.
tf = false;
if folder == "" || ~isfolder(folder); return; end
[~, unique] = fileparts(tempname);
probe = fullfile(folder, "~write_probe_" + unique + ".tmp");
fid = fopen(probe, 'w');
if fid < 0; return; end
fclose(fid);
delete(probe);
tf = true;
end
