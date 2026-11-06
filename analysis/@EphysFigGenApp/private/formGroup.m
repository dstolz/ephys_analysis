function [owner, members] = formGroup(S, k)
%formGroup  The sub-heading row K is under, or the rows under sub-heading K (formSubheading).
%   [OWNER, MEMBERS] = formGroup(S, K) takes row K of the form section S.
%   If K is a sub-heading, OWNER is 0 and MEMBERS are the rows under it (up
%   to the next sub-heading or the section's end). Otherwise MEMBERS is
%   empty and OWNER is the last sub-heading before K -- 0 when there is
%   none, or when it is an end marker (title ""), which closes the group
%   above and titles nothing. The search path, "Go to" and formShown read
%   groups here, as formLayout does.
%
%   See also formSubheading, formRowShown.
owner = 0;
members = zeros(1, 0);
if S.Sub(k)
    next = find(S.Sub(k + 1:end), 1);
    if isempty(next); next = numel(S.Sub) - k + 1; end
    members = k + 1:k + next - 1;
else
    j = find(S.Sub(1:k - 1), 1, 'last');
    if ~isempty(j) && S.SubTitle(j) ~= ""; owner = j; end
end
end
