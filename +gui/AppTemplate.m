classdef AppTemplate < handle
%APPTEMPLATE Template for creating R2015b-style GUIs.

%   Copyright 2016 Matthew R. Eicholtz
    
    properties
        AppName = 'template'; %set default app name here
        GroupName
        ToolGroup
        
        % Handles that are enabled/disabled based on app state
        AllHandles
        TabHandles
        SectionHandles
        
        % Backend handling all computations
        Backend
        
        % Tabs
        % --------------------
        % Define tabs that will appear on the toolstrip, e.g. HomeTab, 
        % VideoTab, RoiTab,...
        Tab1
        ...
        
        % Sections
        % --------------------
        % Define sections for each tab, e.g. FileSection, ViewSection,...
        Section1
        ...
        
        % Widgets
        % --------------------
        % Define any widgets that will go in each section, e.g. buttons,
        % popups, sliders, textboxes, labels,...
        Button1
        ...
        
        % State management
        % --------------------
        % May not be necessary, but in case you want to keep track of the
        % app state.
        CurrentState
        PreviousState
    end
    properties (Dependent=true, SetAccess=private)
    end
    
    
    %======================================================================
    %
    % Public methods
    %
    %======================================================================
    methods
        function this = AppTemplate(varargin)
            % Parse inputs
            if nargin>0
                this.AppName = varargin{1};
            end
            
            % Each tool instance needs a unique name, use tempname
            [~, name] = fileparts(tempname);
            this.GroupName = name;
            this.ToolGroup = toolpack.desktop.ToolGroup(this.GroupName,this.AppName);
            
            % Set tool preferences
            group = this.ToolGroup.Peer.getWrappedComponent; %get group
            group.putGroupProperty(... %remove View tab
                com.mathworks.widgets.desk.DTGroupProperty.ACCEPT_DEFAULT_VIEW_TAB,false);
            group.putGroupProperty(... %remove Quick Access bar
                com.mathworks.widgets.desk.DTGroupProperty.QUICK_ACCESS_TOOL_BAR_FILTER,...
                com.mathworks.toolbox.images.QuickAccessFilter.getFilter());
            group.putGroupProperty(... %remove Document bar
                com.mathworks.widgets.desk.DTGroupProperty.SHOW_SINGLE_ENTRY_DOCUMENT_BAR,false);
            group.putGroupProperty(... %cleanup title
                com.mathworks.widgets.desk.DTGroupProperty.APPEND_DOCUMENT_TITLE,false);
            group.putGroupProperty(... %disable "Hide" option in tabs
                com.mathworks.widgets.desk.DTGroupProperty.PERMIT_DOCUMENT_BAR_HIDE,false);
            group.putGroupProperty(... %disable Drag-Drop gestures on toolgroup
                com.mathworks.widgets.desk.DTGroupProperty.DROP_LISTENER,...
                com.mathworks.widgets.desk.DTGroupProperty.IGNORE_ALL_DROPS);
            
            % Initialize handles structure
            this.TabHandles = struct(...
                'Tab1',[]);
            this.SectionHandles = struct(...
                'Section1',[]);
            
            % Add tabs to tool group
            this.Tab1 = this.ToolGroup.addTab('Tab1','Tab Name');
            
            % Add sections to each tab
            this.Section1 = this.Tab1.addSection('Section1','Section Name');
            
            % Layout each section
            this.layoutSection1();
            
            % Update tab handles
            this.TabHandles.Tab1 = [...
                this.SectionHandles.Section1];
            
            % Update all handles
            this.AllHandles = [...
                this.TabHandles.Tab1];
            
            % Enable/disable controls
            this.state('initial');
            
            % Open tool group
            this.ToolGroup.open
            
            % Hide data browser (can only be done after this.ToolGroup.open)
            md = com.mathworks.mlservices.MatlabDesktopServices.getDesktop;
            md.hideClient('DataBrowserContainer',this.GroupName);
            
            % Set the initial position of the tool and add to tool manager
            imageslib.internal.apputil.ScreenUtilities.setInitialToolPosition(this.GroupName);
            imageslib.internal.apputil.manageToolInstances('add',this.AppName,this);
            
            % Add listeners to ToolGroup
            addlistener(this.ToolGroup,'GroupAction',@this.listenerToolGroup);
            addlistener(this.ToolGroup,'ClientAction',@this.listenerToolGroupClients);
        end
    end
    
    %======================================================================
    %
    % Layout methods
    % ------------------
    % These functions generate the toolstrip layout design, which includes
    % creating widgets (panels, buttons, sliders,...), defining their
    % properties (position, icon,...), and adding listeners for events.
    % Each section in a toolstrip tab should have its own layout method.
    %
    %======================================================================
    methods (Access=private)
        function layoutSection1(this)
            % Create button for loading an image sequence
            this.Button1 = toolpack.component.TSButton('Button Name');
            this.Button1.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.Button1,'Button tooltip');
            addlistener(this.Button1,'ActionPerformed',@this.listenerButton1);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p'); %(columns,rows)
            panel.add(this.Button1,'xy(1,1)');
            
            % Add panel to section
            this.Section1.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.Section1 = {this.Button1};
        end
    end
    
    %======================================================================
    %
    % Listener methods
    % --------------------
    % These functions are called when specific actions are executed in the
    % app, such as clicking on a button or repositioning a slider.
    %
    %======================================================================
    methods (Access=private)
        %******************************************************************
        % Client Handling
        %******************************************************************
        function listenerToolGroup(this,~,evt)
            % Remove app if user interactively closes the ToolGroup.
            if strcmp(evt.EventData.EventType,'CLOSING')
                imageslib.internal.apputil.manageToolInstances('remove',this.AppName,this);
                delete(this);
            end
        end
        function listenerToolGroupClients(this,~,evt)
            % If the figure is closed, restore app to initial state.
            if strcmpi(evt.EventData.EventType,'CLOSED')
                isdeleted = ~isvalid(this) || ~isvalid(this.ToolGroup);
                if ~isdeleted
                    if ~this.ToolGroup.isClientShowing(this.AppName)
                        % The only time this happens is when the user 
                        % clicks 'Yes' on the datalossdlg(). If this 
                        % happens, we should still be in 'wait' mode for 
                        % the user to load an image sequence.
                        this.state('disable all controls');
                    end
                end
            end
        end
        
        %******************************************************************
        % Tab1\Section1
        %******************************************************************
        function listenerButton1(this,obj,evt)
            % Insert code here that will execute when Button1 is clicked.
        end
    end
    
    %======================================================================
    %
    % Other processing methods
    %
    %======================================================================
    methods (Access=private)
        %******************************************************************
        % State Management
        %******************************************************************
        function state(this,str)
            % Enable/disable controls based on app state.
            switch str
                case 'initial'
                    % Do something here...
                otherwise
                    error('Unrecognized state!');
            end
        end
        function status(this,str)
            % Update status bar text.
            iptui.internal.utilities.setStatusBarText(this.GroupName,str);
        end
        
        %******************************************************************
        % Utility
        %******************************************************************
        function this = setTSButtonIconFromImage(this,obj,im)
            % This method allows an image to be set as the icon of a
            % TSButton. There is no direct support for setting a TSButton 
            % icon from a image buffer in memory in the toolstrip API.
            overlayColorButtonJavaPeer = obj.Peer;
            javaImage = im2java(im);
            icon = javax.swing.ImageIcon(javaImage);
            overlayColorButtonJavaPeer.setIcon(icon);
        end
        
    end
    
    %======================================================================
    %
    % Set/Get property methods
    %
    %======================================================================
    methods
    end
    
    %======================================================================
    %
    % Static methods
    %
    %======================================================================
    methods (Static)
    end
    
end

