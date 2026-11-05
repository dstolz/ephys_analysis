function copied = copyFilesToClipboard(files)
%copyFilesToClipboard  Put files on the Windows clipboard, as File Explorer's Copy does.
%   COPIED = copyFilesToClipboard(FILES) puts the files FILES (full paths)
%   on the clipboard as a file list, ready to paste into a folder, an e-mail
%   or a chat, and returns the files the clipboard holds afterwards, read
%   back from it: the ones copied, as a column of strings. Files that are
%   not there are left out. With none left the clipboard is not touched and
%   COPIED is empty. What the clipboard held before is replaced.
%
%   MATLAB's clipboard() takes only text, and the clipboard's file list
%   needs a single-threaded apartment, which MATLAB's thread is not, so
%   Windows PowerShell (-STA) writes it through .NET's
%   System.Windows.Forms.Clipboard. The paths travel in a UTF-8 file, so any
%   character in them survives. Only .NET is used in PowerShell: no cmdlet,
%   which a PowerShell 7 module path could break.
%
%   Windows only. Errors (copyFilesToClipboard:Failed) when PowerShell
%   cannot write the clipboard.
%
%   Example
%       copied = copyFilesToClipboard(["C:\data\a_manifest.json" "C:\data\b_manifest.json"]);
%
%   See also EphysPipelineApp.onCopyManifests, clipboard.
arguments
    files string
end
copied = strings(0, 1);
files = files(:);
files = files(strlength(files) > 0);
files = files(isfile(files));
if isempty(files); return; end
if ~ispc
    error('copyFilesToClipboard:NotWindows', 'Copying files to the clipboard works on Windows only.');
end

tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));
inFile  = fullfile(tmp, 'files.txt');
outFile = fullfile(tmp, 'copied.txt');
script  = fullfile(tmp, 'copy.ps1');
writeUTF8(inFile, files);
writeUTF8(script, [
    "param([string]$InFile, [string]$OutFile)"
    "$ErrorActionPreference = 'Stop'"
    "[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')"
    "$list = [System.Collections.Specialized.StringCollection]::new()"
    "foreach ($p in [System.IO.File]::ReadAllLines($InFile, [System.Text.Encoding]::UTF8)) { if ($p.Trim()) { [void]$list.Add($p.Trim()) } }"
    "$data = [System.Windows.Forms.DataObject]::new()"
    "$data.SetFileDropList($list)"
    "[System.Windows.Forms.Clipboard]::SetDataObject($data, $true, 10, 100)"
    "$back = [string[]]@([System.Windows.Forms.Clipboard]::GetFileDropList())"
    "[System.IO.File]::WriteAllLines($OutFile, $back, [System.Text.UTF8Encoding]::new($false))"
    ]);

ps = fullfile(getenv('SystemRoot'), 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
if ~isfile(ps); ps = 'powershell.exe'; end
cmd = sprintf('"%s" -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "%s" "%s" "%s"', ...
    ps, script, inFile, outFile);
[status, out] = system(cmd);
if status ~= 0 || ~isfile(outFile)
    error('copyFilesToClipboard:Failed', 'The clipboard could not be written: %s', strtrim(out));
end
back = readlines(outFile, "EmptyLineRule", "skip", "Encoding", "UTF-8");
copied = files(ismember(lower(files), lower(strtrim(back))));
end


function writeUTF8(file, lines)
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('copyFilesToClipboard:Failed', 'Could not write %s.', file);
end
fprintf(fid, '%s\r\n', lines);
fclose(fid);
end
