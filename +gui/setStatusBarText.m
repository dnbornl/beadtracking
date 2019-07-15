function setStatusBarText(name,str)
%GUI.SETSTATUSBARTEXT Update status bar in an app.
%   GUI.SETSTATUSBARTEXT(NAME,STR) sets the status bar text of the app 
%   defined by NAME to the input string STR. In this case, NAME refers to 
%   the 'Name' property of the toolpack.desktop.ToolGroup associated with 
%   the app.
%
%   See also IPTUI.INTERNAL.UTILITIES.SETSTATUSBARTEXT.

% Copyright 2014 The MathWorks Inc.
% Modified 2016-2019 Matthew R. Eicholtz

try
    md = com.mathworks.mlservices.MatlabDesktopServices.getDesktop;
    f = md.getFrameContainingGroup(name);
    javaMethodEDT('setStatusText',f,str);
catch
    warning('%s is not working with your current version of MATLAB.',mfilename);
end

end

