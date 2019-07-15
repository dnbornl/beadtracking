function A = cellnum(A)
%CELLNUM Convert numeric array into 1-by-1 cell array.
%   C = CELLNUM(A) places the input numeric array into a 1-by-1 cell array.
%   If the input is already a cell array, the output is unaltered.
%
%   Examples:
%   1) Convert a matrix to a 1-by-1 cell array and then convert it back:
%
%       A = magic(4);
%       C = cellnum(A);
%       B = C{:};
%       assert(isequal(A,B));
%
%   2) Verify that the output of this function does not alter an input cell
%   array:
%
%       A = num2cell(randi(100,1,100));
%       C = cellnum(A);
%       assert(isequal(A,C));
%
%   Notes:
%   1) This function is similar to CELLSTR, but for numeric arrays. Note
%   that it is different from NUM2CELL and MAT2CELL.
%
%   2) Use C{:} to convert the output back to the input.
%
%   See also CELLSTR, MAT2CELL, NUM2CELL.

%   Copyright 2016 Matthew R. Eicholtz

if ~iscell(A)
    A = {A};
end

end

