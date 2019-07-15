function deselect(h)
%DESELECT Select graphics objects.
%   DESELECT(H) sets the 'Selected' property of each input handle to false.
%   The input can be a scalar handle or a cell array of handles. If a
%   handle does not contain the 'Selected' property, it is skipped.
%
%   See also CELLNUM, SELECT.

%   Copyright 2016 Matthew R. Eicholtz

    h = cellnum(h); %convert to cell array if necessary
    for ii=1:numel(h)
        try
            h{ii}.Selected = false;
        end
    end
    
end

