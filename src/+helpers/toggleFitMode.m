function fitmodes = toggleFitMode(fitmodes, fitmode, enable)
%TOGGLEFITMODE Add or remove one fit mode from a selection.
%   fitmodes = helpers.toggleFitMode(fitmodes, fitmode, enable) appends
%   fitmode (deduplicated, kept sorted by enumeration order) when enable
%   is true and removes all occurrences otherwise.
if enable
    fitmodes = unique([fitmodes fitmode]);
else
    fitmodes(fitmodes == fitmode) = [];
end
end
