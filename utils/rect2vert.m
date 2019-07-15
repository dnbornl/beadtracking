function [X,Y] = rect2vert(rect)
%RECT2VERT Convert rectangle position to array of vertices.
%   [X,Y] = RECT2VERT(RECT) returns the rectangular vertices associated 
%   with the position vector RECT. X and Y are sorted in counterclockwise 
%   order, starting from the top-left corner of the rectangle.
%
%   If RECT specifies one rectangle, the outputs are 1-by-4 vectors.
%
%   RECT can also be a M-by-4 matrix, where each row is a position vector.
%   In this case, X and Y are also M-by-4 vectors, where each row contains
%   the vertices for the corresponding row in RECT.
%
%   If less than two outputs are requested and only one rectangle is 
%   specified, the function returns X and Y in a 4-by-2 array.
%
%   If less than two outputs are requested and RECT defines more than one
%   rectangle, the function return X and Y in a 1-by-2 cell array.
%
%   Note: A position vector is a four-element vector [X,Y,WIDTH,HEIGHT],
%   where the point defined by X and Y specifies the top-left corner of the
%   rectangle and WIDTH and HEIGHT refer to rectangle size in the x- and
%   y-direction, respectively.
%
%   See also VERT2RECT, MATSPLIT.

% Copyright 2016 Matthew R. Eicholtz

% Parse inputs
[x,y,wid,hei] = matsplit(rect,1);

% Top-left corner
X(:,1) = x;
Y(:,1) = y;

% Bottom-left corner
X(:,2) = x;
Y(:,2) = y+hei;

% Bottom-right corner
X(:,3) = x+wid;
Y(:,3) = y+hei;

% Top-right corner
X(:,4) = x+wid;
Y(:,4) = y;

% Check output arguments
if nargout<2
    if isvector(rect)
        X = [X(:),Y(:)]; %return X and Y data in a 4-by-2 array
    else
        X = {X,Y}; %return X and Y in a cell array
    end
end

end

