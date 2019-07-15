function varargout = version()
%VERSION Toolbox version information.
%   V = BEADTRACKING.VERSION returns version information for the current
%   installation of the Bead-Tracking Toolbox.
%
%   BEADTRACKING.VERSION, by itself, prints version information directly to
%   the Command Window.

%	Copyright 2016-2019 Matthew R. Eicholtz

p = mfilename('fullpath');
s = fileparts(fileparts(p));

if nargout==0
    disp('-----------------------------------------------------------------------------------------------------');
    disp('Bead-Tracking Toolbox');
    disp('Version 2.0 (2019)');
    disp('Requires:');
    fprintf('\b\tMATLAB (R2019a or later)\n');
    fprintf('\t\t\tComputer Vision Toolbox\n');
    fprintf('\t\t\tImage Processing Toolbox\n');
    fprintf('\t\t\tStatistics and Machine Learning Toolbox\n');
    fprintf('Root directory: %s\n', s);
    disp('-----------------------------------------------------------------------------------------------------');
else
    s = struct('Name','Bead-Tracking Toolbox','Version','2.0','Release','2019','Root',s);
    varargout = {s};
end

end

