function select(h)
%SELECT Select graphics objects.
%   SELECT(H) sets the 'Selected' property of each input handle to true.
%   The input can be a scalar handle or a cell array of handles. If a
%   handle does not contain the 'Selected' property, it is skipped.
%
%   See also CELLNUM, DESELECT.

%   Copyright 2016 Matthew R. Eicholtz

    h = cellnum(h); %convert to cell array if necessary
    for ii=1:numel(h)
        try
            h{ii}.Selected = true;
        end
    end
    
end

