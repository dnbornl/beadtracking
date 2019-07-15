function d = pdist(x)
%PDIST Pairwise distance computation.
%   D = PDIST(X) returns a vector of all pairwise distances for rows in X.
%
%   Notes:
%   1) This function was created as a replacement for the built-in function
%   of the same name, which requires the Statistics and Machine Learning
%   Toolbox.

%   Copyright 2016-2019 Matthew R. Eicholtz

d = utils.pdist2(x,x);
d = d(tril(true(size(d)),-1));
d = d(:)';

end

