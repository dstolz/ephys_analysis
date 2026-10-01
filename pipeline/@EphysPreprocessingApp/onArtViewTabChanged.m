function onArtViewTabChanged(obj)
%onArtViewTabChanged  The Artifacts tab's viewer column switched between its two views.
%   Mark manual periods loads the active dataset's recording (syncArtMark);
%   Detected artifacts stops marking and redraws, as periods marked
%   meanwhile show on it (drawArtifactView).
%
%   See also buildArtifactsTab, syncArtMark.

obj.syncArtMark();
if obj.ArtViewTabs.SelectedTab == obj.ArtTabDetected
    obj.drawArtifactView();
end
end
