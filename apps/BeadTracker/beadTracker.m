function varargout = beadTracker(I)
%BEADTRACKER Detect and analyze individual beads in microscope imagery.
%   BEADTRACKER opens the multiple object tracking app. The user can load
%   an image sequence via the app toolbar.
%
%   BEADTRACKER(I) opens the app and loads the input image sequence.
%
%   BEADTRACKER(FILENAME) reads an image sequence from file, then opens the
%   app and loads the sequence for processing and analysis.
%
%   APP = BEADTRACKER(___) returns the app as output.
%
%   BEADTRACKER CLOSE closes all open bead tracking apps.
%
%   See also IMFRAME, MULTIPLEOBJECTTRACKINGTOOL.

% Copyright 2016-2019 Matthew R. Eicholtz

name = 'Bead Tracker';

if nargin==0
    % Instantiate a new Multiple Object Tracking app
    app = btui.internal.MultipleObjectTrackingTool(name);
else
    % Check possible string input
    if strcmpi(I,'close') %handle 'close' request
        gui.manageToolInstances('deleteAll',name);
        return;
    elseif ischar(I) %try loading image sequence from file
        try
            I = imframe(I,'all','class','same');
        catch
            error('Failed to load file: %s\nCheck inputs.',I);
        end
    end
    
    % Validate image sequence input
    classes    = {'uint8','uint16','double'};
    attributes = {'real','nonsparse','nonempty','ndims',4};
    validateattributes(I,classes,attributes,mfilename,'I');
    
    % Start app
    app = btui.internal.MultipleObjectTrackingTool(name,I);
end

% Return app as output, if requested
varargout = {app};

end

