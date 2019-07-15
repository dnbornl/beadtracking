function cleanup()
%CLEANUP Start with a clean slate.
%   CLEANUP() clears the MATLAB Workspace, Command Window, closes any open
%   figures, closes any open Bead Tracker apps, and deletes any hanging 
%   waitbars (i.e. from program aborts).

% Copyright 2019 Matthew R. Eicholtz

evalin('base','clear');
clc;
close all;
delete(findall(0,'type','figure','tag','TMWWaitbar'));
gui.manageToolInstances('deleteAll','Bead Tracker');

end

