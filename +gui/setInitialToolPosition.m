function setInitialToolPosition(groupName)
%GUI.SETINITIALTOOLPOSITION Set the initial position of an app.
%   GUI.SETINITIALTOOLPOSITION(GROUPNAME) updates the default location of a
%   tool given by its GROUPNAME. For dual monitor setups, this function
%   only updates the tool position for Linux OS.

% Copyright The MathWorks, Inc.
% Modified 2017-2019 Matthew R. Eicholtz

% Get desktop object
md = com.mathworks.mlservices.MatlabDesktopServices;

% Check monitors
monitorPositions = get(0,'MonitorPositions');
isDualMonitor = size(monitorPositions,1) > 1;
               
% Do not manipulate tool size for any dual monitor setup unless it's on Linux
if ~strcmp(computer('arch'),'glnxa64') && isDualMonitor     
   return;
end

% Handle dual monitors on Linux
if strcmp(computer('arch'),'glnxa64') && isDualMonitor                
    sz = monitorPositions(1,:); % query primary monitor                
else % single monitor, all platforms
    sz = get(0,'ScreenSize');
end

% Set minimum size to use for the tool
szMinWidth  = 1280;
szMinHeight = 768;

% Get actual monitor size
szWidth  = sz(3);
szHeight = sz(4);

% Occupy 70% of the screen real estate or whatever is the minimum size defined above
width  = max(szMinWidth,round(szWidth*0.7));
height = max(szMinHeight,round(szHeight*0.7));

if isDualMonitor             
    % Must use Java coordinate system, which is different from that of HG
    if monitorPositions(2) < 0
        % If secondary monitor is to the left, it will have negative x offset
        sz = sz + [abs(monitorPositions(2)) 0 0 0];
    end
end                

x = sz(1) + round(szWidth/2) - round(width/2);
y = sz(2) + round(szHeight/2) - round(height/2);

% Create DTFloatingLocation object for tool position
loc = com.mathworks.widgets.desk.DTLocation.createExternal(...
    int16(x),int16(y),int16(width),int16(height));

% Set group location
md.setGroupLocation(groupName,loc);

end

