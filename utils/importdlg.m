function [x,name] = importdlg(varargin)
%IMPORTDLG Import data from workspace dialog box.
%   IMPORTDLG displays a dialog box for selecting a variable from the
%   MATLAB workspace.
%
%   [X,NAME] = IMPORTDLG returns the value and name of the selected
%   variable. If the user exits the dialog box prior to selecting a 
%   variable (either by clicking 'Cancel' or closing the figure), then X
%   and NAME are returned empty.
%
%   See also IPTUI.INTERNAL.IMGETVAR.

%   Copyright 2016 Matthew R. Eicholtz

%% Parse inputs
%-------------------------------------------------------------
%    This needs to be fixed. Currently does nothing useful
narginchk(0,1);
if nargin==1
    % client needs to be a figure
    hFig = varargin{1};
    iptcheckhandle(hFig,{'figure'},mfilename,'hfigure',1);
end
%-------------------------------------------------------------

%% Define relevant parameters
hei = 360; wid = 360; %figure size
dx = 12; %left and right margins
dy = 12; %top and bottom margins
spacing = 4; %for layout purposes

buttonwid = 60; buttonhei = 25; %button size

%other sizing variables
filterpanelhei = 40;
pmenuhei = 20;

options = {'All','4D'}; %filters

%% Create figure
hfigure = figure(...
    'Toolbar','none',...
    'Menubar','none',...
    'NumberTitle','off',...
    'IntegerHandle','off',...
    'Tag','importdlg',...
    'Visible','on',...
    'HandleVisibility','callback',...
    'Name','Import From Workspace',...
    'WindowStyle','modal',...
    'Position',getcenter([wid hei]),...
    'Resize','off',...
    'Color',get(0,'FactoryFigureColor'));
setappdata(hfigure,'x',[]);
setappdata(hfigure,'name','');

%% Create filter dropdown menu
hfilterpanel = uipanel(... %panel containing uicontrols for filtering
    'Parent',hfigure,...
    'Units','pixels',...
    'BorderType','none',...
    'Position',[dx, hei-filterpanelhei-dy, wid-2*dx, filterpanelhei],...
    'Tag','filterpanel');
iptui.internal.setChildColorToMatchParent(hfilterpanel,hfigure);

hfilterlabel = uicontrol(... %static text label
    'Parent',hfilterpanel,...
    'Style','Text',...
    'String','Filter:',...
    'Units','pixels',...
    'HorizontalAlignment','left');
hfilterlabel.Position = [dx, (filterpanelhei-hfilterlabel.Extent(4))/2-spacing, hfilterlabel.Extent(3:4)];
iptui.internal.setChildColorToMatchParent(hfilterlabel,hfilterpanel);

hfiltermenu = uicontrol(... %drop-down menu
    'Parent',hfilterpanel,...
    'Style','popupmenu',...
    'String',options,...
    'Callback',@showpanel,...
    'Units','pixels',...
    'Position',[hfilterlabel.Position(1)+hfilterlabel.Extent(3)+spacing,...
                (filterpanelhei-pmenuhei)/2,wid-4*dx-hfilterlabel.Extent(3)-spacing,pmenuhei],...
    'Tag','filtermenu');
iptui.internal.setChildColorToMatchParent(hfiltermenu,hfilterpanel);
if ispc
    % For Windows machines, set background color of popupmenu to white to
    % match imgetfile dialog style
    hfiltermenu.BackgroundColor = 'white';
end

%% Create button panel
hbuttonpanel = uipanel(... %panel containing OK and Cancel buttons
    'Parent',hfigure,...
    'Units','pixels',...
    'BorderType','none',...
    'Position',[dx,dy,wid-2*dx,buttonhei],...
    'Tag','buttonpanel');
iptui.internal.setChildColorToMatchParent(hbuttonpanel,hfigure);

buttonstrs = {'OK','Cancel'};
buttontags = {'okbutton','cancelbutton'};
nb = length(buttonstrs);
buttonspacing = (wid-2*dx-nb*buttonwid)/(nb+1);
hbutton = gobjects(nb,1);
for ii=1:nb
    hbutton(ii) = uicontrol(... %add each button with appropriate spacing
        'Parent',hbuttonpanel,...
        'Style','pushbutton',...
        'String',buttonstrs{ii},...
        'Position',[buttonspacing*ii+buttonwid*(ii-1),0,buttonwid,buttonhei],...
        'Callback',@buttonpress,...
        'Tag',buttontags{ii});
    iptui.internal.setChildColorToMatchParent(hbutton(ii),hbuttonpanel);
end

%% Create display panel(s)
hdisplaypanel = gobjects(size(options));
hdisplaylabel = gobjects(size(options));
hvarlist = gobjects(size(options));
for ii=1:length(options)
    if ii==1
        vis = 'on';
    else
        vis = 'off';
    end
    
    hdisplaypanel(ii) = uipanel(... %panel containing workspace variable lists
        'Parent',hfigure,...
        'Units','pixels',...
        'BorderType','none',...
        'Position',[dx,2*dy+buttonhei,wid-2*dx,hei-filterpanelhei-buttonhei-4*dy],...
        'Visible',vis,...
        'Tag',sprintf('displaypanel%s',lower(options{ii})));
    iptui.internal.setChildColorToMatchParent(hdisplaypanel(ii),hfigure);
    
    hdisplaylabel(ii) = uicontrol(... %static text label
        'Parent',hdisplaypanel(ii),...
        'Style','text',...
        'String','Variables:',...
        'Units','pixels',...
        'HorizontalAlignment','left');
    hdisplaylabel(ii).Position = [dx, hdisplaypanel(ii).Position(4)-hdisplaylabel(ii).Extent(4)-spacing, hdisplaylabel(ii).Extent(3:4)];
    iptui.internal.setChildColorToMatchParent(hdisplaylabel(ii),hdisplaypanel(ii));
    
    hvarlist(ii) = uicontrol(... %list of applicable variables
        'Parent',hdisplaypanel(ii),...
        'Style','listbox',...
        'BackgroundColor','white',...
        'FontName','Courier',...
        'Value',1,...
        'Units','pixels',...
        'Callback',@highlightlist,...
        'Tag',sprintf('list%s',lower(options{ii})));
    hvarlist(ii).Position = [dx, 0.1, hdisplaypanel(ii).Position(3)-2*dx, hdisplaypanel(ii).Position(4)-hdisplaylabel(ii).Extent(4)-spacing];
    iptui.internal.setChildColorToMatchParent(hvarlist(ii),hdisplaypanel(ii));

    % Get indices corresponding to valid variables
    [ws,names] = wsvars();
    switch lower(options{ii})
        case 'all'
            ind = 1:length(names);
        case '4d'
            mask = cellfun(@length,{ws.size})==4;
            ind = find(mask);
        otherwise
            error('Unrecognized filter option: %s\n',options{ii});
    end
    iptui.internal.displayVarsInList(ws(ind),hvarlist(ii));
end

%% Show figure and wait until user closes the tool
hfigure.Visible = 'on';
uiwait(hfigure);

%% Return output
x = getappdata(hfigure,'x');
name = getappdata(hfigure,'name');
close(hfigure);

end

%% Helper functions
function buttonpress(obj,evt) %#ok<INUSD>
    % Callback function for the OK and Cancel buttons
    handles = guihandles;
    hfigure = handles.importdlg;
    switch obj.Tag
        case 'okbutton'
            [success,x,name] = getvar();
            if success
                setappdata(hfigure,'x',x);
                setappdata(hfigure,'name',name);
                uiresume(hfigure);
            end
        case 'cancelbutton'
            uiresume(hfigure);
    end
end
function [out,success] = evalvar(name)
    % Try to evaluate the specified variable in the base workspace
    success = true;
    out = [];
    try
        out = evalin('base',sprintf('%s;',name));
    catch ME
        errordlg(ME.message)
        success = false;
    end
end
function pos = getcenter(sz)
    % Returns the position of the dialog box centered on the screen.
    old_units = get(0,'Units');
    set(0,'Units','Pixels');
    screen_size = get(0,'ScreenSize');
    set(0,'Units', old_units);
    
    lower_left_pos = 0.5*(screen_size(3:4)-sz);
    pos = [lower_left_pos sz];
end
function [success,x,name] = getvar()
    % Get variable
    success = true; %#ok<NASGU>
    x = [];
    name = [];
    
    hactivepanel = findobj('-regexp','Tag','displaypanel','Visible','on'); %active panel
    hactivevarlist = findobj(hactivepanel,'Type','uicontrol','Style','listbox','Visible','on'); %active variable list
    liststr = hactivevarlist.String; %list of variables
    if isempty(liststr) %return if there are no variables listed in current panel
        if isempty(evalin('base','whos'))
            errorstr = getString(message('images:privateUIString:noVariablesErrorStr'));
        else
            errorstr = getString(message('images:privateUIString:noSelectedVariableStr'));
        end
        errordlg(errorstr);
        success = false;
        return;
    end

    name = strtok(liststr{hactivevarlist.Value}); %variable name
    [x,success] = evalvar(name);
end
function highlightlist(obj,evt) %#ok<INUSD>
    % Callback for listboxes containing workspace variables
    if isempty(obj.String); return; end
    
    hfigure = obj.Parent.Parent; %figure handle
    double_click = strcmp(hfigure.SelectionType,'open'); %was it a double click
    clicked_same_list_item = (hfigure.UserData==obj.Value);
    
    [success,x,name] = getvar();
    if double_click && clicked_same_list_item && success
        setappdata(hfigure,'x',x);
        setappdata(hfigure,'name',name);
        uiresume(hfigure);
    else
        hfigure.SelectionType = 'normal';
    end
    
    hfigure.UserData = obj.Value;
end
function showpanel(obj,evt) %#ok<INUSD>
    % Edit import panel based on filter menu selection
    name = lower(obj.String{obj.Value}); %which option is selected?
    hdisplaypanels = findobj('-regexp','Tag','displaypanel');
    mask = ~cellfun('isempty',regexp({hdisplaypanels.Tag},name));
    
    hdisplaypanels(mask).Visible = 'on';
    hdisplaypanels(~mask).Visible = 'off';
%     set(display_panels(ind),'Visible','on');
%     set(display_panels(ind ~= 1:num_of_panels),'Visible','off');
end
function [ws,names] = wsvars()
    % Function to retrieve workspace variable structure and variable names.
    ws = evalin('base','whos');
    N = length(ws); %number of variables
    [names{1:N}] = deal(ws.name);
end

