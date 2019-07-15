classdef Icon < handle
%GUI.ICON Object class for toolstrip icons.
%
%   Notes:
%   1) This class relies upon the toolpack.component.Icon class.
%
%   Examples:
%   1) Create an icon using optional arguments of filename and description:
%
%       filename = fullfile(beadtracking.path,'resources','icons','Freehand_16.png');
%       description = 'My icon';
%
%       icon = gui.Icon
%       icon = gui.Icon(filename)
%       icon = gui.Icon(filename, description)
%
%   2) Create a common icon using a static method call:
%
%       icon = gui.Icon.FREEHAND_16
%
%   See also TOOLPACK.COMPONENT.ICON.

% Author(s): Bora Eryilmaz
% Revised: 2016-2019 Matthew R. Eicholtz
% Copyright 2010-2013 The MathWorks, Inc.

    properties (Dependent, Access = public)
        % Brief description of the icon (string, default = '')
        Description
    end

    properties (Hidden, Dependent, GetAccess = public, SetAccess = protected)
        % Component peer (read-only, default = empty ImageIcon)
        Peer
    end
    
    properties (Access = private)
        % An ImageIcon or [] for default value empty ImageIcon
        Peer_
    end

    properties (Constant, Hidden, Access=public)
        % Path to resources directory for icons
        Path = fullfile(beadtracking.path,'resources','icons');
    end
  
    methods
        function this = Icon(filename, description)
        % Creates an icon component.
            if nargin == 0
                % Icon()
                this.Peer = [];
            elseif nargin == 1
                if isempty(filename)
                    % Icon([])
                    this.Peer = [];  % javax.swing.ImageIcon([]) will hang command line!
                elseif ischar(filename)
                    if exist(filename, 'file')
                        % Icon(filename)
                        this.Peer = javax.swing.ImageIcon(filename);
                    else
                        error(message('Controllib:toolpack:CannotLocateFile', filename));
                    end
                else
                    % INTERNAL USE ONLY: Icon(imageicon)
                    imageicon = filename;
                    this.Peer = imageicon;
                end
            else
                if isempty(filename)
                    % Icon([], description)
                    this.Peer = [];  % javax.swing.ImageIcon([]) will hang command line!
                    this.Description = description;
                elseif ischar(filename)
                    if exist(filename, 'file')
                        % Icon(filename, description)
                        this.Peer = javax.swing.ImageIcon(filename, description);
                    else
                        error(message('Controllib:toolpack:CannotLocateFile', filename));
                    end
                else
                    % INTERNAL USE ONLY: Icon(imageicon, description)
                    imageicon = filename;
                    this.Peer = imageicon;
                    this.Description = description;
                end
            end
        end
    
    function value = get.Peer(this)
      % GET function for Peer property.
      value = this.Peer_;
      if isempty(value)
        % Default peer: empty ImageIcon
        value = javax.swing.ImageIcon;
        this.Peer_ = value; % Do not recreate an empty icon every time.
      end
    end
    
    function set.Peer(this, value)
      % SET function for Peer property.
      if isempty(value)
        value = []; % Will reset the peer to new empty ImageIcon.
      elseif ~isa(value, 'javax.swing.ImageIcon')
        error(message('Controllib:toolpack:InvalidPropertyValue', 'Peer'));
      end
      this.Peer_ = value;
    end
    
    function value = get.Description(this)
      % GET function for Description property.
      value = char(this.Peer.getDescription);
    end
    
    function set.Description(this, value)
      % SET function for Description property.
      if isempty(value)
        value = '';
      elseif ~ischar(value)
        error(message('Controllib:toolpack:StringArgumentNeeded'));
      end
      this.Peer.setDescription(value);
    end
    end
  
    methods (Static)
        function icon = getIcon(filename)
            % Helper method to get standard icons.
            iconfile = fullfile(gui.Icon.Path,filename);
            icon = toolpack.component.Icon(iconfile);
        end
        function showIcons
            % Helper method to show all standard icons on a figure window.
            clsName = 'toolpack.component.Icon';
            gui.Icon.showIcons_(clsName);
        end
    end

    methods (Sealed, Static)
        function icon = ADJUSTLEVELS_24
            icon = gui.Icon.getIcon('AdjustLevels_24.png');
        end
        function icon = BLOBS_16
            icon = gui.Icon.getIcon('Blobs_16.png');
        end
        function icon = CLOSE_16
            icon = gui.Icon.getIcon('Close_16.png');
        end
        function icon = CLOSE_24
            icon = gui.Icon.getIcon('Close_24.png');
        end
        function icon = CONFIRM_16
            icon = gui.Icon.getIcon('Confirm_16.png');
        end
        function icon = CONFIRM_24
            icon = gui.Icon.getIcon('Confirm_24.png');
        end
        function icon = EXPORT_16
            icon = gui.Icon.getIcon('Export_16.png');
        end
        function icon = EXPORT_24
            icon = gui.Icon.getIcon('Export_24.png');
        end
        function icon = FREEHAND_16
            icon = gui.Icon.getIcon('Freehand_16.png');
        end
        function icon = FREEHAND_24
            icon = gui.Icon.getIcon('Freehand_24.png');
        end
        function icon = HELP_16
            icon = gui.Icon.getIcon('Help_16.png');
        end
        function icon = HELP_24
            icon = gui.Icon.getIcon('Help_24.png');
        end
        function icon = IMPORT_16
            icon = gui.Icon.getIcon('Import_16.png');
        end
        function icon = IMPORT_24
            icon = gui.Icon.getIcon('Import_24.png');
        end
        function icon = NEXT_16
            icon = gui.Icon.getIcon('Next_16.png');
        end
        function icon = PAN_16
            icon = gui.Icon.getIcon('Pan_16.png');
        end
        function icon = PAUSE_16
            icon = gui.Icon.getIcon('Pause_16.png');
        end
        function icon = PAUSE_24
            icon = gui.Icon.getIcon('Pause_24.png');
        end
        function icon = PLAY_16
            icon = gui.Icon.getIcon('Play_16.png');
        end
        function icon = PLAY_24
            icon = gui.Icon.getIcon('Play_24.png');
        end
        function icon = POLYGON_16
            icon = gui.Icon.getIcon('Polygon_16.png');
        end
        function icon = POLYGON_24
            icon = gui.Icon.getIcon('Polygon_24.png');
        end
        function icon = PREV_16
            icon = gui.Icon.getIcon('Prev_16.png');
        end
        function icon = RECTANGLE_16
            icon = gui.Icon.getIcon('Rectangle_16.png');
        end
        function icon = RECTANGLE_24
            icon = gui.Icon.getIcon('Rectangle_24.png');
        end
        function icon = REFRESH_16
            icon = gui.Icon.getIcon('Refresh_16.png');
        end
        function icon = RUN_24
            icon = gui.Icon.getIcon('Run_24.png');
        end
        function icon = SAVE_16
            icon = gui.Icon.getIcon('Save_16.png');
        end
        function icon = SAVE_24
            icon = gui.Icon.getIcon('Save_24.png');
        end
        function icon = SETTINGS_16
            icon = gui.Icon.getIcon('Settings_16.png');
        end
        function icon = SETTINGS_24
            icon = gui.Icon.getIcon('Settings_24.png');
        end
        function icon = SHOWAREA_24
            icon = gui.Icon.getIcon('ShowArea_24.png');
        end
        function icon = SHOWBINARY_24
            icon = gui.Icon.getIcon('ShowBinary_24.png');
        end
        function icon = SHOWPERIMETER_24
            icon = gui.Icon.getIcon('ShowPerimeter_24.png');
        end
        function icon = UNDO_16
            icon = gui.Icon.getIcon('Undo_16.png');
        end
        function icon = UNDO_24
            icon = gui.Icon.getIcon('Undo_24.png');
        end
        function icon = ZOOMIN_16
            icon = gui.Icon.getIcon('Zoom_In_16.png');
        end
        function icon = ZOOMOUT_16
            icon = gui.Icon.getIcon('Zoom_Out_16.png');
        end
    end
  
  methods (Static, Access = protected)
    function showIcons_(clsName)
      % Find all static methods returning an icon.
      info = meta.class.fromName(clsName);
      list = info.MethodList;
      [~, I] = sort({list.Name});
      list = list(I);
      
      mthd = {};
      for k = 1:length(list)
        m = list(k);
        if m.Static && isempty(m.InputNames) && ...
            ~isempty(m.OutputNames) && strcmp(m.OutputNames, 'icon')
          % Static methods returning icons have no inputs and have "icon"
          % as the output argument.
          mthd{end+1} = m.Name;
        end
      end
      
      % Add icons to a panel
      len = ceil(length(mthd)/5); % 5 columns and as many rows as needed.
      f = '';
      for k = 1:len
        f = sprintf('%sf:d:g,',f);
      end
      f(end) = ''; % Remove last ','.
      panel = toolpack.component.TSPanel('f:d:g,f:d:g,f:d:g,f:d:g,f:d:g',f);
      for k = 1:length(mthd)
        try
          icon = eval([clsName, '.' mthd{k}]);
          label = toolpack.component.TSLabel(mthd{k}, icon);
        catch E
          % Icon not implemented yet.
          fprintf('%s\n', E.message);
          label = toolpack.component.TSLabel(mthd{k});
        end
        i = rem(k-1,5); % col
        j = (k-i-1)/5;  % row
        str = sprintf('xy(%d,%d)', i+1, j+1);
        panel.add(label,str);
      end
      
      % Show icons on a panel
      fig = figure(...
        'IntegerHandle','off', ...
        'Menubar','None',...
        'Toolbar','None',...
        'Name','Icon Catalog. To use: toolpack.component.Icon.<NAME>', ...
        'NumberTitle','off', ...
        'Visible','on', ...
        'Resize', 'on', ...
        'Units','pixels');
      set(fig, 'ResizeFcn', @localFigureResize)
      pos = get(fig, 'Position');
      scroll = javaObjectEDT('javax.swing.JScrollPane', panel.Peer);
      [~, container] = javacomponent(scroll,[0 0 pos(3) pos(4)],fig);
      set(fig, 'UserData', {panel, container});
    end
  end
end

% ----------------------------------------------------------------------------
function localFigureResize(fig,~)
% Handle figure resize
pos = get(fig, 'Position');
ud  = get(fig, 'UserData');
container = ud{2};
set(container, 'Position', [0 0 pos(3) pos(4)]);
end

