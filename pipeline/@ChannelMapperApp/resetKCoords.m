function resetKCoords(obj)
%resetKCoords  Back to the design's shanks as the Kilosort4 kcoords groups.
obj.KCoords = zeros(0, 1);
obj.KCoordsFor = "";
obj.resolve();
end
