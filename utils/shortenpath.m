function y = shortenpath(x)
%SHORTENPATH Condense pathname to parent directory and filename.
%   Y = SHORTENPATH(X) returns a string in which all intermediate
%   directories in the input have been replaced by '...'.
%
%   It is assumed that X is a typical pathname string using the delimiter
%   '\' to identify directories.
%
%   X can also be a cell array of pathname strings, in which case the
%   output Y is also a cell array of shortened pathname strings and Y{i} is
%   the condensed version of X{i}.
%
%   Notes:
%   1) See the associated Cody problem on the MathWorks website:
%   http://www.mathworks.com/matlabcentral/cody/problems/2625-shorten-pathname

%   Copyright 2016 Matthew R. Eicholtz

y = regexprep(x,'\\.*\\','\\...\\');

end

