function d = pdist2(x,y)
%PDIST2 Pairwise distance computation.
%   D = PDIST2(X,Y) returns an M-by-N matrix corresponding to the pairwise
%   distances between the M-by-K array X and the N-by-K array Y, where K is
%   the dimensionality of the data samples.
%
%   Notes:
%   1) This function was created as a replacement for the built-in function
%   of the same name, which requires the Statistics and Machine Learning
%   Toolbox.

%   Copyright 2016 Matthew R. Eicholtz

m = size(x,1); n = size(y,1);
X = sum(x.*x,2);
Y = sum(y'.*y',1);
d = X(:,ones(1,n)) + Y(ones(1,m),:) - 2*x*y';
d = sqrt(d);

end

