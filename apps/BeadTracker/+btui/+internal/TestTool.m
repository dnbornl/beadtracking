classdef TestTool < handle
%MULTIPLEOBJECTTRACKINGTOOL Track multiple objects in an image sequence.

%   Copyright 2016 Matthew R. Eicholtz
    
    properties
        % Main
        AppName = 'app';
        GroupName
        ToolGroup
        
        % Tabs
        HomeTab
        
        % Sections
        FileSection
        VideoControlsSection
        ZoomPanSection
        
        % State management
        CurrentState
        PreviousState
        
        % Backend handling all computations.
        Backend
        
        % Cache colormap to use original colormap after exiting ShowBinary
        % mode.
        Colormap
        
        % Handles that are enabled/disabled based on app state
        AllHandles
        TabHandles
        SectionHandles
        
        % Cache knowledge of whether we normalized double input data so
        % that we can have thresholds in "generate function" context match
        % image data. Do the same for massaging of image data to handle
        % Nans and Infs appropriately.
        IsDataNormalized
        IsInfNanRemoved
    end
    properties (Dependent=true, SetAccess=private)
        AxesHandle
        ImageHandle
    end
    properties
        LoadButton
    end
    properties (Access=private,Constant)
        LoadButtonIcon          = isml.gui.Icon.IMPORT_24;
        LoadButtonPopupIcon     = isml.gui.Icon.IMPORT_16;
        
        
        LoadButtonStr                   = sprintf('Load Image\nSequence');
        LoadButtonToolTipText           = 'Load image sequence from workspace or file';
        LoadButtonStatusBarText1        = 'Select an image sequence to load...';
        LoadButtonStatusBarText2        = 'Loading image sequence...';
        LoadButtonPopupOption1          = 'Load Image Sequence From File';
        LoadButtonPopupOption2          = 'Load Image Sequence From Workspace';
        DataLossDlgTitle                = 'Load New Image Sequence?';
        DataLossDlgQuestion             = 'Loading a new image sequence will cause all data in existing session to be deleted. Do you want to continue?';
        InvalidImageDlgMessage          = 'Input image sequence must be 4-D array of class uint8, uint16 or double. Please choose a valid image sequence.';
        InvalidImageDlgTitle            = 'Unsupported image type';
        NormalizeDataDlgMessage         = sprintf(['Input double image '...
                                            'contains values outside the range [0 1]. Would you '...
                                            'like to normalize image data to the range [0 1] to '...
                                            'continue?\n\nNote that image data containing NaN '...
                                            'values will be treated as 0, +Inf values will be '...
                                            'treated as 1 and -Inf as 0.']);
        NormalizeDataDlgTitle           = 'Normalize Image?';
        NormalizeDataDlgOption          = 'Normalize Image';
    end
    
    methods
        function this = TestTool(varargin)
            % Parse inputs
            if nargin==1
                this.AppName = varargin{1};
            elseif nargin==2
                this.AppName = varargin{1};
                im = varargin{2};
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
                'Home',[]);
            this.SectionHandles = struct(...
                'File',[],...
                'VideoControls',[],...
                'ZoomPan',[]);
            
            % Add tabs to tool group
            this.HomeTab        = this.ToolGroup.addTab('HomeTab','Home');
            
            % Add sections to each tab
            this.FileSection            = this.HomeTab.addSection('FileSection','File');
            this.VideoControlsSection   = isml.gui.VideoManager(this,this.HomeTab); %attach VideoManager to corresponding section
            this.ZoomPanSection         = isml.gui.ZoomPanManager(this,this.HomeTab); %attach ZoomPanManager to corresponding section
            
            % Layout each section
            this.layoutFileSection();
            
            % Update section handles
            this.SectionHandles.VideoControls = this.VideoControlsSection.Handles;
            this.SectionHandles.ZoomPan = this.ZoomPanSection.Handles;
            
            % Update tab handles
            this.TabHandles.Home = [...
                this.SectionHandles.File,...
                this.SectionHandles.VideoControls,...
                this.SectionHandles.ZoomPan];
            
            % Update all handles
            this.AllHandles = [...
                this.TabHandles.Home];
            
            % Enable/disable controls
            this.state('initial'); %waits for user to load an image sequence
            
            % Open tool group
            this.ToolGroup.open
            
            % Hide data browser (can only be done after this.ToolGroup.open)
            md = com.mathworks.mlservices.MatlabDesktopServices.getDesktop;
            md.hideClient('DataBrowserContainer',this.GroupName);
            
            % Set the initial position of the tool and add to tool manager
            imageslib.internal.apputil.ScreenUtilities.setInitialToolPosition(this.GroupName);
            imageslib.internal.apputil.manageToolInstances('add',this.AppName,this);
            
            % If image data was specified, load it into the app
            if exist('im','var')
                [this,im] = normdlg(this,im);
                this.initializeAppWithImage(im);
            end
            
            % Add listeners to ToolGroup
            addlistener(this.ToolGroup,'GroupAction',@this.listenerToolGroup);
            addlistener(this.ToolGroup,'ClientAction',@this.listenerToolGroupClients);
        end
        function initializeAppWithImage(this,im)
            % Initialize tracking backend with image
            this.Backend = btui.internal.MultipleObjectTrackingBackend(im);
            
            % Create image display
            this.Backend.hfigure = createTrackingView(this);
            
            % Update controls after loading image
            this.state('image loaded'); %resets all controls and makes image editable
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
        function layoutFileSection(this)
            % Create button for loading an image sequence
            this.LoadButton = toolpack.component.TSSplitButton(this.LoadButtonStr,this.LoadButtonIcon);
            this.LoadButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.LoadButton,this.LoadButtonToolTipText);
            addlistener(this.LoadButton,'ActionPerformed',@this.listenerLoadButton);
            
            % Add popup menu to button
            items(1) = struct(...
                'Title',this.LoadButtonPopupOption1,...
                'Description','',...
                'Icon',this.LoadButtonPopupIcon,...
                'Help',[],...
                'Header',false);
            items(2) = struct(...
                'Title',this.LoadButtonPopupOption2,...
                'Description','',...
                'Icon',this.LoadButtonPopupIcon,...
                'Help',[],...
                'Header',false);
            this.LoadButton.Popup = toolpack.component.TSDropDownPopup(items,'icon_text');
            addlistener(this.LoadButton.Popup,'ListItemSelected',@this.listenerLoadButtonPopup);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p'); %(columns,rows)
            panel.add(this.LoadButton,'xy(1,1)');
            
            % Add panel to section
            this.FileSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.File = {this.LoadButton};
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
        % Home\File
        %******************************************************************
        function listenerLoadButton(this,~,~)
            % Load image sequence from file.
            imload(this,'from file');
        end
        function listenerLoadButtonPopup(this,obj,~)
            % Respond to user popup selection.
            if obj.SelectedIndex==1 %load image sequence from file
                imload(this,'from file');
            elseif obj.SelectedIndex==2 %load image sequence from workspace
                imload(this,'from workspace');
            end
        end
    end
    
    
    
    %======================================================================
    %
    % Other processing methods
    %
    %======================================================================
    methods (Access=private)
        %******************************************************************
        % Figure Display
        %******************************************************************
        function hfigure = createTrackingView(this)
            % Instantiate figure
            hfigure = figure(...
                'NumberTitle','off',...
                'Name',this.AppName,...
                'Colormap',gray(2),...
                'IntegerHandle','off');
            
            % Set the WindowKeyPressFcn to a non-empty function. This is
            % effectively a no-op that executes everytime a key is pressed
            % when the App is in focus. This is done to prevent focus from
            % shifting to the MATLAB command window when a key is typed.
            hfigure.WindowKeyPressFcn = @(~,~)[];
            
            % Add the figure to the toolgroup
            this.ToolGroup.addFigure(hfigure);
            
            % Unregister image in drag and drop gestures when figures are docked in toolgroup
            this.ToolGroup.getFiguresDropTargetHandler.unregisterInterest(hfigure);
            
            % Install mouse pointer manager in figure
            iptPointerManager(hfigure);
            
            % Add panel for image display and setup layout
            impanel = uipanel(...
                'Parent',hfigure,...
                'Position',[0 0 1 1],...
                'BorderType','none',...
                'Tag','ImagePanel');
            if isempty(this.Backend.hScrollPanel) || ~ishandle(this.Backend.hScrollPanel)
                % Create axes
                haxes = axes('Parent',impanel);
                
                % Figure will be docked before imshow is invoked. We want
                % to avoid warning about fit mag in context of a docked
                % figure.
                warnstate = warning('off','images:imshow:magnificationMustBeFitForDockedFigure');
                
                % We do not want to autoscale uint8, but want to autoscale 
                % uint16 and double.
                if isa(this.Backend.ImageSequence,'uint8')
                    himage = imshow(this.Backend.CurrentImage,'Parent',haxes);
                else
                    himage = imshow(this.Backend.CurrentImage,'Parent',haxes,'DisplayRange',[]);
                end
                warning(warnstate);
                
                % Add the scroll panel
                this.Backend.hScrollPanel = imscrollpanel(impanel,himage);
                this.Backend.hScrollPanel.Units = 'normalized';
                this.Backend.hScrollPanel.Position = [0 0 1 1];
                
                % We need to ensure that graphics objects related to the
                % scroll panel are constructed before we set the
                % magnification of the tool.
                drawnow; drawnow;
                
                % Get API for scroll panel and set magnification
                % appropriately.
                api = iptgetapi(this.Backend.hScrollPanel);
                fitmag = api.findFitMag();
                api.setMagnification(fitmag);
                
                % Modify axes
                haxes = findobj(this.Backend.hScrollPanel,'type','axes');
                set(haxes,'Visible','on'); %turn on visibility
                set(haxes,'XTick',[],'YTick',[]); %turn off grid
            else
                % If scrollpanel has already been created, we simply want
                % to reparent it to the current figure that is being
                % created/in view.
                set(this.Backend.hScrollPanel,'Parent',impanel);
            end
            
            % Cache colormap for update after 'ShowBinary'
            this.Colormap = get(hfigure,'Colormap');
            
            % Prevent MATLAB graphics from being drawn in figures docked within app
            set(hfigure,'HandleVisibility','callback');
        end
        
        %******************************************************************
        % Loading an image sequence
        %******************************************************************
        function usercanceled = datalossdlg(this)
            % Query user to continue with data loss or not.
            usercanceled = false;
            if this.ToolGroup.isClientShowing(this.AppName)
                answer = questdlg(this.DataLossDlgQuestion,...
                    this.DataLossDlgTitle,...
                    getString(message('images:commonUIString:yes')),...
                    getString(message('images:commonUIString:cancel')),...
                    getString(message('images:commonUIString:cancel')));
                if strcmp(answer,getString(message('images:commonUIString:yes')))              
                    try pausevideo(this.Backend); end %try to stop current video if one is playing
                    validhandles = ishandle(this.Backend.hfigure);
                    close(this.Backend.hfigure(validhandles));
                    this.Backend.hfigure = [];
                else %user selected cancel
                    usercanceled = true;
                end
            end
        end
        function imload(this,location)
            % Load an image sequence.
            this.status(this.LoadButtonStatusBarText1);
            this.state('disable all controls'); %disable all controls until loading is complete
            
            usercanceled = this.datalossdlg(); %check if user wants to proceed with data loss
            if ~usercanceled %user clicked yes
                switch location
                    case 'from file'
                        % Query user to select image sequence from file
                        currdir = cd;
                        cd(fullfile(btui.path,'resources','demos'));
                        [filename,pathname] = uigetfile(...
                            {'*.jpg;*.tif;*.png;*.gif','All Image Files'; '*.*','All Files'},...
                            'Load Image Sequence From File');
                        cd(currdir);
%                         filename = imgetfile();
                        if ~isempty(filename) && ~isequal(filename,0)
                            im = imframe(fullfile(pathname,filename),'all','class','uint8');
                        else
                            im = [];
                        end
                    case 'from workspace'
                        % Query user to select image sequence from workspace
                        im = importdlg();
                end
                
                if ~isempty(im)
                    isvalidtype = btui.internal.TestTool.isvalidimage(im);
                    if ~isvalidtype
                        errdlg = errordlg(this.InvalidImageDlgMessage,this.InvalidImageDlgTitle,'modal');
                        % We need the error dialog to be blocking, otherwise
                        % listenerLoadButton() is invoked before the dialog finishes
                        % setting itself up and becomes modal.
                        uiwait(errdlg);
                        % Drawnow is necessary so that imgetfile dialog will
                        % enforce modality in next call to imgetfile that
                        % arises from recursion.
                        drawnow;
                        imload(this,location);
                        return;
                    else                        
                        [this,im] = normdlg(this,im);
                        this.status(this.LoadButtonStatusBarText2);
                        this.initializeAppWithImage(im);
                    end
                else
                    this.state('initial');
                end
            else %user canceled datalossdlg
                this.state('idle');
            end
            
            this.status('');
        end
        function [this,im] = normdlg(this,im)
            % Query user to normalize double data.
            this.IsDataNormalized = false;
            this.IsInfNanRemoved = false;
            if isa(im,'double')
                % Check if image has NaN,Inf or -Inf valued pixels.
                finiteIdx = isfinite(im(:));
                hasNansInfs	= ~all(finiteIdx);

                % Check if image pixels are outside [0,1].
                isOutsideRange = any(im(finiteIdx)>1) || any(im(finiteIdx)<0);

                % Offer the user the option to normalize and clean-up data
                % if either of these conditions is true.
                if isOutsideRange || hasNansInfs                
                    answer = questdlg(this.NormalizeDataDlgMessage,...
                        this.NormalizeDataDlgTitle,...
                        this.NormalizeDataDlgOption,...
                        getString(message('images:commonUIString:cancel')),...
                        this.NormalizeDataDlgOption);
                    if strcmp(answer,this.NormalizeDataDlgOption)
                        % First clean-up data by removing NaNs and Infs.
                        if hasNansInfs
                            im(isnan(im)) = 0; %replace nan pixels with 0.
                            im(im==Inf) = 1; %replace inf pixels with 1.
                            im(im==-Inf) = 0; %replace -inf pixels with 0.
                            this.IsInfNanRemoved = true;
                        end

                        % Normalize data in [0,1] if outside range.
                        if isOutsideRange
                            im = im./max(im(:));
                            this.IsDataNormalized = true;
                        end
                    else
                        im = [];
                    end
                end
            end
        end
        
        %******************************************************************
        % State Management
        %******************************************************************
        function state(this,str)
            % Enable/disable controls based on app state.
            if strcmp(str,'previous')
                str = this.PreviousState;
            end
            switch str
                case 'wait for response'
                    disable(this.AllHandles);
                    enable(this.SectionHandles.VideoControls); %allow video controls
                    
                case 'idle'
                    % This is the state in which an image is in view, so
                    % enable all image editing controls, but do not reset
                    % default values.
                    enable(this.TabHandles.Home);
                    
                case 'image loaded'
                    
                    % Enable relevant controls
                    enable(this.TabHandles.Home);
                    
                    % Default settings
                    this.ZoomPanSection.default();
                    
                    % Update PreviousState
                    this.PreviousState = str;
                    
                case 'initial'
                    disable(this.AllHandles);
                    enable(this.SectionHandles.File); %allow user to load an image sequence
                    
                    % Default settings
                    this.ZoomPanSection.default();
                    
                case 'roi loaded'
                    enable(this.TabHandles.Home);
                    
                case 'disable all controls'
                    disable(this.AllHandles);
                    
                case 'enable all usable controls'
                    enable(this.AllHandles);
                    
                otherwise
                    error('Unrecognized state!');
                    
            end
            
            % Update current state
            this.CurrentState = str;
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
        function h = get.AxesHandle(this)
            h = findobj(this.Backend.hScrollPanel,'type','axes');
        end
        function h = get.ImageHandle(this)
            h = findobj(this.Backend.hScrollPanel,'type','image');
        end
    end
    
    
    %======================================================================
    %
    % Static methods
    %
    %======================================================================
    methods (Static)
        function tf = isvalidimage(im)
            % Check if input image is valid data type.
            supportedDataType	= isa(im,'uint8') || isa(im,'uint16') || isa(im,'double');
            supportedAttributes	= isreal(im) && all(isfinite(im(:))) && ~issparse(im) && ndims(im)==4;
            
            tf = supportedDataType && supportedAttributes;
        end
    end
    
    
end

