%beadTrackerDemo
%   This script demonstrates the beadTracker app, which enables the
%   detection and tracking of microscopic objects in image sequences.
%
%   See also beadTracker, btui.internal.MultipleObjectTrackingTool.

% Copyright 2016-2019 Matthew R. Eicholtz
cleanup;

% Set parameters
option = 2; %see options below
filename = fullfile(beadtracking.path,'resources','demos','motion03.tif');

% Close all current instances of the beadTracker app
beadTracker close;

switch option
    case 1
        % Start app with no inputs; in this case, you can load an image
        % sequence using the interface tools on the HOME tab.
        app = beadTracker();
        
    case 2
        % Start app with input filename
        app = beadTracker(filename);
        
    case 3
        % Start app with input image sequence
        I = tiffread(filename,'squeeze',false);
        app = beadTracker(I);
        
    otherwise
        error('Unrecognized option: %d',option);
end

