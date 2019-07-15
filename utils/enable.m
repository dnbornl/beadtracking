function enable(h)
%ENABLE Enable graphics objects.
%   ENABLE(H) sets the 'Enabled' property of each input handle to true.
%   The input can be a scalar handle or a cell array of handles. If a
%   handle does not contain the 'Enabled' property, it is skipped.
%
%   See also CELLNUM, DISABLE.

%   Copyright 2016 Matthew R. Eicholtz

    h = cellnum(h); %convert to cell array if necessary
    for ii=1:numel(h)
        try
            h{ii}.Enabled = true;
        end
    end
    
end

