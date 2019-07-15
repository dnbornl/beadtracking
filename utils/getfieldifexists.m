function f = getfieldifexists(s,field)
%GETFIELDIFEXISTS Extract field of structure if it exists.
%   F = GETFIELDIFEXISTS(S,FIELD) returns the field contents in an input
%   structure, if that field exists. If the field does not exist, the
%   output is empty.
%
%   Example:
%   s = struct('field1',1,'field2',2);
%   f1 = getfieldifexists(s,'field1');
%   f3 = getfieldifexists(s,'field3');
%   f1 =
%       1
%   f3 = 
%       []
%
%   See also GETFIELD, ISFIELD.

% Copyright 2016 Matthew R. Eicholtz

if isfield(s,field)
    f = s.(field);
else
    f = [];
end

end

