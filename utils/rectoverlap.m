function C = rectoverlap(A,B)
%RECTOVERLAP Rectangle area percent overlap.
%   C = RECTOVERLAP(A,B) returns the percentage of area overlap of the
%   rectangles specified by position vectors A and B, relative to the area
%   of rectangle B.
%
%   If A and B each specify one rectangle, the output C is a scalar.
%
%   A and B can also be matrices, where each row is a position vector. C is
%   then a matrix giving the percent overlap of all pairs of rectangles
%   from A and B. That is, if A is M-by-4 and B is N-by-4, then C is an 
%   M-by-N matrix where C(P,Q) is the percent overlap of the rectangles
%   specified by the Pth row of A and the Qth row of B, relative to the Qth
%   row of B.
%
%   Note: A position vector is a four-element vector [X,Y,WIDTH,HEIGHT],
%   where the point defined by X and Y specifies the top-left corner of the
%   rectangle and WIDTH and HEIGHT refer to rectangle size in the x- and
%   y-direction, respectively.
%
%   See also RECTINT.

% Copyright 2016 Matthew R. Eicholtz

narginchk(2,2);

areaAB = rectint(A,B); %intersection area
% areaB = diag(rectint(B,B)); %area of B (NOTE: this line of code may cause OUT OF MEMORY ERROR)
[X,Y] = rect2vert(B); %convert B from position vector(s) to vertices
areaB = polyarea(X,Y,2); %area of B
C = bsxfun(@rdivide,areaAB,areaB(:)');

end

