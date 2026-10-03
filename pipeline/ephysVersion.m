function info = ephysVersion()
%ephysVersion  The version of this code: its release number and git checkout.
%   INFO = ephysVersion() returns a struct with
%     Version     the release number, "major.minor.patch", read from the
%                 VERSION file at the repository root ("" when that file is
%                 missing or does not hold a major.minor.patch number, with
%                 the warning ephysVersion:BadVersionFile). Raise it there
%                 when a release is cut (see CHANGELOG.md).
%     Commit      short hash of the commit checked out ("" when git cannot
%                 tell: a zip download, or no git on the PATH)
%     CommitDate  that commit's date, yyyy-MM-dd ("" likewise)
%     Branch      the branch checked out ("" when detached or unknown)
%     Dirty       true when tracked files have uncommitted changes
%     Describe    git describe --tags --always --dirty: the nearest release
%                 tag, the commits since it and the commit, e.g.
%                 "v0.1.0-12-g34e8f4a-dirty"; just the commit while no tag
%                 exists ("" when git cannot tell)
%     Folder      the repository folder
%     Text        all of it on one line, e.g.
%                 "0.1.0 (commit 34e8f4a on main, 2026-09-22)"
%
%   The Help menu's About item (showAbout), bug reports (issueReport) and
%   the provenance every output records (ephysProvenance) show it.
%
%   See also ephysProvenance.

info = struct('Version', "", 'Commit', "", 'CommitDate', "", ...
    'Branch', "", 'Dirty', false, 'Describe', "", 'Folder', "", 'Text', "");

here = fileparts(mfilename('fullpath'));   % pipeline/
info.Folder = string(fileparts(here));

versionFile = fullfile(info.Folder, "VERSION");
v = "";
if isfile(versionFile)
    v = strtrim(string(fileread(versionFile)));
end
if ~isempty(regexp(v, '^\d+\.\d+\.\d+$', 'once'))
    info.Version = v;
else
    warning('ephysVersion:BadVersionFile', ...
        '%s is missing or does not hold a major.minor.patch number; the version is unknown.', versionFile);
end

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
        [st, desc] = system(sprintf('git -C "%s" describe --tags --always --dirty --abbrev=7', here));
        desc = strtrim(string(desc));
        if st == 0 && ~contains(desc, newline); info.Describe = desc; end
    end
catch err
    warning('ephysVersion:GitFailed', 'Could not ask git which commit this is: %s', err.message);
end

info.Text = info.Version;
if info.Text == ""; info.Text = "unknown version"; end
if info.Commit ~= ""
    detail = "commit " + info.Commit;
    if info.Branch ~= ""; detail = detail + " on " + info.Branch; end
    detail = detail + ", " + info.CommitDate;
    if info.Dirty; detail = detail + ", with uncommitted changes"; end
    info.Text = info.Text + " (" + detail + ")";
end
end
