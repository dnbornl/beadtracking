function disable(h)
%DISABLE Disable graphics objects.
%   DISABLE(H) sets the 'Enabled' property of each input handle to false.
%   The input can be a scalar handle or a cell array of handles. If a
%   handle does not contain the 'Enabled' property, it is skipped.
%
%   See also CELLNUM, ENABLE.

%   Copyright 2016 Matthew R. Eicholtz

    h = cellnum(h); %convert to cell array if necessary
    for ii=1:numel(h)
        try
            h{ii}.Enabled = false;
        end
    end
    
end

