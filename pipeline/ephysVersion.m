function info = ephysVersion()
%ephysVersion  The version of this code: its release number and git checkout.
%   INFO = ephysVersion() returns a struct with
%     Version     the release number, "major.minor.patch". It is set by hand
%                 below; raise it when a release is cut.
%     Commit      short hash of the commit checked out ("" when git cannot
%                 tell: a zip download, or no git on the PATH)
%     CommitDate  that commit's date, yyyy-MM-dd ("" likewise)
%     Branch      the branch checked out ("" when detached or unknown)
%     Dirty       true when tracked files have uncommitted changes
%     Folder      the repository folder
%     Text        all of it on one line, e.g.
%                 "0.1.0 (commit 34e8f4a on main, 2026-09-22)"
%
%   The Help menu's About item (showAbout) and bug reports (issueReport)
%   show it.

info = struct('Version', "0.1.0", 'Commit', "", 'CommitDate', "", ...
    'Branch', "", 'Dirty', false, 'Folder', "", 'Text', "");

here = fileparts(mfilename('fullpath'));   % pipeline/
info.Folder = string(fileparts(here));

try
    [st, out] = system(sprintf('git -C "%s" log -1 --format="%%h %%cs"', here));
    parts = split(strtrim(string(out)));
    if st == 0 && numel(parts) == 2 && ~isempty(regexp(parts(1), '^[0-9a-f]{7,40}$', 'once'))
        info.Commit = parts(1);
        info.CommitDate = parts(2);
        [st, branch] = system(sprintf('git -C "%s" rev-parse --abbrev-ref HEAD', here));
        branch = strtrim(string(branch));
        if st == 0 && branch ~= "HEAD"; info.Branch = branch; end
        [st, dirty] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no', here));
        info.Dirty = st == 0 && strlength(strtrim(string(dirty))) > 0;
    end
catch
end

info.Text = info.Version;
if info.Commit ~= ""
    detail = "commit " + info.Commit;
    if info.Branch ~= ""; detail = detail + " on " + info.Branch; end
    detail = detail + ", " + info.CommitDate;
    if info.Dirty; detail = detail + ", with uncommitted changes"; end
    info.Text = info.Text + " (" + detail + ")";
end
end
