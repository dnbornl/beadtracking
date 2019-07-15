function varargout = path()
%PATH Root directory.
%   S = BTUI.PATH returns the root directory of the app as a string.
%
%   BTUI.PATH, by itself, prints the root directory fullpath to the Command 
%   Window.

%	Copyright 2016 Matthew R. Eicholtz

p = mfilename('fullpath');
s = fileparts(fileparts(p));

if nargout==0
    disp(s);
else
    varargout = {s};
end

end

