function openInSystem(target)
%openInSystem  Open a folder or file the way the operating system does.
%   openInSystem(TARGET) shows a folder in the file browser, or opens a file
%   in its default program: winopen on Windows, open on macOS, xdg-open on
%   Linux (in the background). An error (openInSystem:Missing, or
%   openInSystem:Failed with the system's message) says why it could not.
%
%   See also platformSupport.

arguments
    target (1,1) string
end
if ~(isfolder(target) || isfile(target))
    error('openInSystem:Missing', 'There is nothing at %s.', target);
end
if ispc
    winopen(char(target));
    return
end
if ismac
    [status, msg] = system(sprintf('open "%s"', target));
else
    [status, msg] = system(sprintf('xdg-open "%s" > /dev/null 2>&1 &', target));
end
if status ~= 0
    error('openInSystem:Failed', 'Could not open %s: %s', target, strtrim(msg));
end
end
