classdef MultipleObjectTrackingTool_old < handle
%BTUI.INTERNAL.MULTIPLEOBJECTTRACKINGTOOL Track multiple objects in an
%image sequence.

% Copyright 2016-2019 Matthew R. Eicholtz
    
    properties
        % Main
        AppName = 'Multiple Object Tracker';
        GroupName
        ToolGroup
        DataPath = fullfile(beadtracking.path,'data');
        
        % Tabs
        HomeTab
        RoiTab
        OpticalFlowTab
        TrackingTab
        
        % Sections
        FileSection
        VideoControlsSection
        ZoomPanSection
        OptionsSection
        
        % State management
        CurrentState
        PreviousState
        
        % Handles that are enabled/disabled based on app state
        AllHandles
        TabHandles
        SectionHandles
        
        % Backend handling all computations.
        Backend
        
        % Cache colormap to use original colormap after exiting ShowBinary
        % mode.
        Colormap
        
        % Cache knowledge of whether we normalized double input data so
        % that we can have thresholds in "generate function" context match
        % image data. Do the same for massaging of image data to handle
        % Nans and Infs appropriately.
        IsDataNormalized
        IsInfNanRemoved
        
        % Flag to cache whether RGB image was loaded into App.
        wasRGB
    end
    properties (Access=private)
        VideoCurrentFrameListener
        RoiColorListener
        RoiFlagListener
        RoiMaskListener
        OpticalFlowColorListener
        OpticalFlowFlagListener
        OpticalFlowLinewidthListener
        TrackingColorListener
        TrackingOpacityListener
        TrackingLinewidthListener
        TrackingFlagListener
        TrackingDetectionsListener
        
        % Used to record segment/refine actions performed. This is needed
        % for generating code.
        EventLog
    end
    properties (Dependent=true, SetAccess=private)
        AxesHandle
        ImageHandle
        OpticalFlowHandle
        DetectionHandle
    end
    
    
    %======================================================================
    %
    % Widgets
    % ---------
    % Define relevant widgets used throughout the app, such as buttons,
    % sliders, labels, popup menus, text boxes, etc.
    %
    %======================================================================
    properties
        % Home\File
        LoadButton
        
        % Home\Options
        RoiCheckBox
        OpticalFlowCheckBox
        DetectionCheckBox
        TrackingCheckBox
    end
    
    
    %======================================================================
    %
    % Icons
    % ---------
    % Define relevant icons used throughout the app.
    %
    %======================================================================
    properties (Access=private,Constant)
        % Home\File
        LoadButtonIcon          = gui.Icon.IMPORT_24;
        LoadButtonPopupIcon     = gui.Icon.IMPORT_16;
    end
    
    
    %======================================================================
    %
    % Strings
    % -----------
    % Define relevant strings used throughout the app; for example, widget
    % labels and tooltiptext.
    %
    %======================================================================
    properties (Access=private,Constant)
        % Home\File
        LoadButtonStr                   = sprintf('Load Image\nSequence');
        LoadButtonToolTipText           = 'Load image sequence from workspace or file';
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
        
        % Home\Options
        RoiCheckBoxStr                  = 'ROI';
        RoiCheckBoxToolTipText          = 'Show the selected region of interest';
        OpticalFlowCheckBoxStr        	= 'Optical Flow';
        OpticalFlowCheckBoxToolTipText  = 'Show optical flow velocity vectors on the image';
        DetectionCheckBoxStr            = 'Detection';
        DetectionCheckBoxToolTipText    = 'Show detected objects on the image';
        TrackingCheckBoxStr             = 'Tracking';
        TrackingCheckBoxToolTipText     = 'Show tracking results on the image';
    end
    
    
    %======================================================================
    %
    % Defaults
    % ------------
    % Define relevant default parameter values used throughout the app; for
    % instance, the initial values of sliders or editable text boxes.
    %
    %======================================================================    
    properties (Access=private,Constant)
        % Home\Options
        RoiCheckBoxDefault              = false;
        OpticalFlowCheckBoxDefault      = false;
        DetectionCheckBoxDefault        = false;
        TrackingCheckBoxDefault         = false;
    end
    
    
    %======================================================================
    %
    % Public methods
    %
    %======================================================================
    methods
        function this = MultipleObjectTrackingTool_old(varargin)
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
            this.setpref();
            
            % Add tabs to tool group
            this.HomeTab        = this.ToolGroup.addTab('HomeTab','Home');
            this.RoiTab         = gui.RoiManager(this,this.ToolGroup); %attach RoiManager to corresponding tab
            this.OpticalFlowTab = gui.OpticalFlowManager(this,this.ToolGroup); %attach OpticalFlowManager to corresponding tab
            this.TrackingTab    = gui.TrackingManager(this,this.ToolGroup); %attach TrackingManager to corresponding tab
            
            % Add sections to each tab
            this.FileSection            = this.HomeTab.addSection('FileSection','File');
            this.VideoControlsSection   = gui.VideoManager(this.HomeTab); %attach VideoManager to corresponding section
            this.ZoomPanSection         = gui.ZoomPanManager_old(this,this.HomeTab); %attach ZoomPanManager_old to corresponding section
            this.OptionsSection         = this.HomeTab.addSection('OptionsSection','Options');
            
            % Layout each section
            this.layoutFileSection();
            this.layoutOptionsSection();
            
            % Create handles structures
            this.updatehandles();
            
            % Open tool group
            this.ToolGroup.open
            
            % Enable/disable controls
            this.state('initialize the app');
            
            % Hide data browser (can only be done after this.ToolGroup.open)
            md = com.mathworks.mlservices.MatlabDesktopServices.getDesktop;
            md.hideClient('DataBrowserContainer',this.GroupName);
            
            % Set the initial position of the tool and add to tool manager
            imageslib.internal.apputil.ScreenUtilities.setInitialToolPosition(this.GroupName);
            gui.manageToolInstances('add',this.AppName,this);
            
            this.addlisteners();
            
            % If image data was specified, load it into the app
            if exist('im','var')
                [this,im] = normdlg(this,im);
                this.initializeAppWithImage(im);
            end
        end
        function initializeAppWithImage(this,im)
            this.status('Loading image sequence...');
            
            % Initialize tracking backend with image
            this.Backend = btui.internal.MultipleObjectTrackingBackend(im);
            
            % Update ROI mask (but do not automatically show ROI)
            sz = this.Backend.ImageSize;
            this.RoiTab.Mask = true(sz);
            this.RoiCheckBox.Selected = false;
            
            % Update Optical Flow vectors
            this.OpticalFlowTab.OpticalFlow = opticalFlow(zeros(sz),zeros(sz));
            
            % Create image display
            this.Backend.hfigure = createTrackingView(this);
            
            % Update controls after loading image
            this.state('image sequence has been loaded'); %resets all controls and makes image editable
        end
        function state(this,str)
            % Enable/disable controls based on app state.
            if strcmp(str,'previous')
                str = this.PreviousState;
            end
            switch str
                case 'wait for response'
                    disable(this.AllHandles);
                    disable(this.ZoomPanSection);
                    reset(this.ZoomPanSection);
                    
                    enable(this.VideoControlsSection); %allow video controls
                    enable(this.SectionHandles.ROI.Response); %wait for user response
                    
                case 'idle'
                    % This is the state in which an image is in view, so
                    % enable all image editing controls, but do not reset
                    % default values.
                    enable(this.TabHandles.Home);
                    
                    enable(this.VideoControlsSection);
                    enable(this.ZoomPanSection);
                    
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    enable(this.TabHandles.Tracking);
                    disable(this.SectionHandles.ROI.Response);
                    
                case 'image sequence has been loaded'
                    % Enable relevant controls
                    enable(this.TabHandles.Home);
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    enable(this.TabHandles.Tracking);
                    
                    disable(this.SectionHandles.ROI.Response);
                    
                    % Return to default parameter values
                    this.VideoControlsSection.setNumberOfFrames(this.Backend.NumFrames);
                    reset(this.VideoControlsSection);
                    reset(this.ZoomPanSection);
%                     this.RoiTab.reset();
                    
                    % Update PreviousState
                    this.PreviousState = str;
                    
                case 'initialize the app'
                    disable(this.AllHandles);
                    enable(this.SectionHandles.File); %allow user to load an image sequence
                    this.status('Load an image sequence by clicking on Home->File->Load Image Sequence');
                    
                case 'roi loaded'
                    enable(this.TabHandles.Home);
                    enable(this.VideoControlsSection);
                    enable(this.ZoomPanSection);
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    enable(this.TabHandles.Tracking);
                    disable(this.SectionHandles.ROI.Response);
                    
                case 'detections loaded'
                    enable(this.TabHandles.Home);
                    enable(this.VideoControlsSection);
                    enable(this.ZoomPanSection);
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    enable(this.TabHandles.Tracking);
                    disable(this.SectionHandles.ROI.Response);
                    
                case 'disable all controls'
                    disable(this.AllHandles);
                    
                case 'enable all usable controls'
                    enable(this.AllHandles);
                    disable(this.SectionHandles.ROI.Response);
                    
                case 'saving roi data to file'
                    disable(this.AllHandles);
                    this.status('Saving ROI data to file...');
                    
                case 'selecting an image sequence to load'
                    disable(this.AllHandles);
                    this.status('Select an image sequence to load...');
                    
                case 'selecting roi data to load'
                    disable(this.AllHandles);
                    this.status('Select ROI data to load...');
                    
                case 'user canceled datalossdlg'
                    enable(this.TabHandles.Home);
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    enable(this.TabHandles.Tracking);
                    
                    disable(this.SectionHandles.ROI.Response);
                    
                case 'waiting for user to load an image sequence'
                    disable(this.AllHandles);
                    enable(this.SectionHandles.File);
                    this.status('Load an image sequence by clicking on Home->File->Load Image Sequence');
                    
                otherwise
                    error('Unrecognized state!');
                    
            end
            
            % Update current state
            this.CurrentState = str;
        end
    end
    methods (Access=private)
        function addlisteners(this)
            % Add listeners to ToolGroup
            addlistener(this.ToolGroup,'GroupAction',@this.listenerToolGroup);
            addlistener(this.ToolGroup,'ClientAction',@this.listenerToolGroupClients);
            
            % Add property listeners for child objects
            this.VideoCurrentFrameListener = event.proplistener(this.VideoControlsSection,...
                this.VideoControlsSection.findprop('CurrentFrame'),'PostSet',@this.listenerVideoCurrentFrame);
            
            this.RoiColorListener = event.proplistener(this.RoiTab,...
                this.RoiTab.findprop('Color'),'PostSet',@this.listenerRoiColor);
            this.RoiFlagListener = event.proplistener(this.RoiTab,...
                this.RoiTab.findprop('Flag'),'PostSet',@this.listenerRoiFlag);
            this.RoiMaskListener = event.proplistener(this.RoiTab,...
                this.RoiTab.findprop('Mask'),'PostSet',@this.listenerRoiFlag);
            
            this.OpticalFlowColorListener = event.proplistener(this.OpticalFlowTab,...
                this.OpticalFlowTab.findprop('Color'),'PostSet',@this.listenerOpticalFlowColor);
            this.OpticalFlowFlagListener = event.proplistener(this.OpticalFlowTab,...
                this.OpticalFlowTab.findprop('Flag'),'PostSet',@this.listenerOpticalFlowFlag);
            this.OpticalFlowLinewidthListener = event.proplistener(this.OpticalFlowTab,...
                this.OpticalFlowTab.findprop('Linewidth'),'PostSet',@this.listenerOpticalFlowLinewidth);
            
            this.TrackingColorListener = event.proplistener(this.TrackingTab,...
                this.TrackingTab.findprop('Color'),'PostSet',@this.listenerTrackingColor);
            this.TrackingOpacityListener = event.proplistener(this.TrackingTab,...
                this.TrackingTab.findprop('Opacity'),'PostSet',@this.listenerTrackingOpacity);
            this.TrackingLinewidthListener = event.proplistener(this.TrackingTab,...
                this.TrackingTab.findprop('Linewidth'),'PostSet',@this.listenerTrackingLinewidth);
            this.TrackingFlagListener = event.proplistener(this.TrackingTab,...
                this.TrackingTab.findprop('TrackingFlag'),'PostSet',@this.listenerTrackingFlag);
            this.TrackingDetectionsListener = event.proplistener(this.TrackingTab,...
                this.TrackingTab.findprop('Detections'),'PostSet',@this.listenerTrackingDetections);
        end
        function setpref(this)
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
        end
        function updatehandles(this)
            % Update handle structures. The reason for having these
            % structures is to make it easier to disable/enable groups of
            % widgets depending on app state.
            
            % Section handles
            this.SectionHandles.ROI             = this.RoiTab.Handles;
            this.SectionHandles.OpticalFlow     = this.OpticalFlowTab.Handles;
            
            % Tab handles
            this.TabHandles.Home = [ ...
                this.SectionHandles.File, ...
                this.VideoControlsSection.Handles, ...
                this.ZoomPanSection.Handles, ...
                this.SectionHandles.Options];
            this.TabHandles.ROI = this.RoiTab.Handles.All;
            this.TabHandles.OpticalFlow = this.OpticalFlowTab.Handles.All;
            this.TabHandles.Tracking = this.TrackingTab.Handles.All;
            
            % All handles
            this.AllHandles = [...
                this.TabHandles.Home,...
                this.TabHandles.ROI,...
                this.TabHandles.OpticalFlow,...
                this.TabHandles.Tracking];
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
        function layoutOptionsSection(this)
            % Create checkboxes for each option
            this.RoiCheckBox = toolpack.component.TSCheckBox(this.RoiCheckBoxStr,this.RoiCheckBoxDefault);
            iptui.internal.utilities.setToolTipText(this.RoiCheckBox,this.RoiCheckBoxToolTipText);
            addlistener(this.RoiCheckBox,'ItemStateChanged',@this.listenerRoiCheckBox);
            
            this.OpticalFlowCheckBox = toolpack.component.TSCheckBox(this.OpticalFlowCheckBoxStr,this.OpticalFlowCheckBoxDefault);
            iptui.internal.utilities.setToolTipText(this.OpticalFlowCheckBox,this.OpticalFlowCheckBoxToolTipText);
            addlistener(this.OpticalFlowCheckBox,'ItemStateChanged',@this.listenerOpticalFlowCheckBox);
            
            this.DetectionCheckBox = toolpack.component.TSCheckBox(this.DetectionCheckBoxStr,this.DetectionCheckBoxDefault);
            iptui.internal.utilities.setToolTipText(this.DetectionCheckBox,this.DetectionCheckBoxToolTipText);
            addlistener(this.DetectionCheckBox,'ItemStateChanged',@this.listenerDetectionCheckBox);
            
            this.TrackingCheckBox = toolpack.component.TSCheckBox(this.TrackingCheckBoxStr,this.TrackingCheckBoxDefault);
            iptui.internal.utilities.setToolTipText(this.TrackingCheckBox,this.TrackingCheckBoxToolTipText);
            addlistener(this.TrackingCheckBox,'ItemStateChanged',@this.listenerTrackingCheckBox);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,3dlu','f:p:g,f:p:g,f:p:g,f:p:g'); %(columns,rows)
            panel.add(this.RoiCheckBox,         'xy(1,1)');
            panel.add(this.OpticalFlowCheckBox, 'xy(1,2)');
            panel.add(this.DetectionCheckBox,   'xy(1,3)');
            panel.add(this.TrackingCheckBox,    'xy(1,4)');
            
            % Add panel to section
            this.OptionsSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.Options = {...
                this.RoiCheckBox,...
                this.OpticalFlowCheckBox,...
                this.DetectionCheckBox,...
                this.TrackingCheckBox};
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
                gui.manageToolInstances('remove',this.AppName,this);
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

        %******************************************************************
        % Home\Options
        %******************************************************************
        function listenerRoiCheckBox(this,obj,~)
            % Toggle overlay of selected region of interest on image.
            if ~isvalid(this); return; end %return if app is closed
            
            if obj.Selected
                this.showRoi();
            else
                this.hideRoi();
            end
        end
        function listenerOpticalFlowCheckBox(this,obj,~)
            % Overlay the optical flow velocity vectors on the image.
            if ~isvalid(this); return; end %return if app is closed
            
            if obj.Selected
                t1 = this.VideoControlsSection.CurrentFrame;
                im0 = this.Backend.ImageSequence(:,:,:,max(1,t1-1));
                im1 = this.Backend.ImageSequence(:,:,:,t1);
                this.OpticalFlowTab.updateFlow(im1,im0);
                this.showOpticalFlow();
            else
                this.hideOpticalFlow();
            end
        end
        function listenerDetectionCheckBox(this,obj,~)
            % Toggle overlay of detected objects on the image.
            if ~isvalid(this); return; end %return if app is closed
            
            if obj.Selected
                this.showDetections();
            else
                this.hideDetections();
            end
        end
        function listenerTrackingCheckBox(this,obj,evt)
            % Overlay the tracked objects on the image.
            
        end
        
        %******************************************************************
        % VideoManager
        %******************************************************************
        function listenerVideoCurrentFrame(this,~,~)
            % Update graphics in app after CurrentFrame is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            % Check if current frame is different from previous frame
            t0 = this.VideoControlsSection.PreviousFrame;
            t1 = this.VideoControlsSection.CurrentFrame;
            if t0==t1
%                 fprintf('%s\tWhy is listenerVideoCurrentFrame being called on the same frame?\n',datestr(now));
                return;
            end
            im1 = this.Backend.ImageSequence(:,:,:,t1);
            
            % Update image
            himage = this.ImageHandle;
            if isvalid(himage)
                himage.CData = im1;
                himage.CDataMapping = 'scaled';
            end
            
            % Update optical flow
            if this.OpticalFlowCheckBox.Selected
                if (t1-t0)==1
                    this.OpticalFlowTab.updateFlow(im1);
                else
                    im0 = this.Backend.ImageSequence(:,:,:,max(1,t1-1));
                    this.OpticalFlowTab.updateFlow(im1,im0);
                end
                this.showOpticalFlow();
            else
                this.hideOpticalFlow();
            end
            
            % Update detections
            if this.DetectionCheckBox.Selected
                this.showDetections();
            else
                this.hideDetections();
            end
        end
        
        %******************************************************************
        % RoiManager
        %******************************************************************
        function listenerRoiColor(this,~,~)
            % Update region of interest color when it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            this.AxesHandle.Color = this.RoiTab.Color;
        end
        function listenerRoiFlag(this,~,~)
            % Update region of interest whenever it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            if ~this.RoiCheckBox.Selected
                this.RoiCheckBox.Selected = true;
            else
                this.showRoi();
            end
        end
        
        %******************************************************************
        % OpticalFlowManager
        %******************************************************************
        function listenerOpticalFlowColor(this,~,~)
            % Update optical flow color when it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            this.OpticalFlowHandle.Color = this.OpticalFlowTab.Color;
        end
        function listenerOpticalFlowFlag(this,~,~)
            % Update optical flow whenever it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            if ~this.OpticalFlowCheckBox.Selected
                this.OpticalFlowCheckBox.Selected = true;
            else
                this.showOpticalFlow();
            end
        end
        function listenerOpticalFlowLinewidth(this,~,~)
            % Update optical flow line width when it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            this.OpticalFlowHandle.LineWidth = this.OpticalFlowTab.Linewidth;
        end
        
        %******************************************************************
        % TrackingManager
        %******************************************************************
        function listenerTrackingColor(this,~,~)
            % Update detection color when it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            this.DetectionHandle.FaceColor = this.TrackingTab.Color;
            this.DetectionHandle.EdgeColor = max(0,this.TrackingTab.Color-0.2);
        end
        function listenerTrackingOpacity(this,~,~)
            % Update detection opacity when it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            this.DetectionHandle.FaceAlpha = this.TrackingTab.Opacity;
        end
        function listenerTrackingLinewidth(this,~,~)
            % Update detection linewidth when it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            this.DetectionHandle.LineWidth = this.TrackingTab.Linewidth;
        end
        function listenerTrackingFlag(this,~,~)
            % Update detections whenever it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            disable(this.AllHandles);
            
            % Insert tracking code here
            I = this.Backend.ImageSequence;
            X = this.TrackingTab.Detections;
            roi = this.RoiTab.Mask;
            if ~isempty(X)
                thold = this.TrackingTab.Threshold;
                centroids = cell(size(X));
                bboxes = cell(size(X));
                for ii=1:length(X)
                    xy = X{ii}(:,1:2);
                    r = X{ii}(:,3);
                    score = X{ii}(:,4);

                    t = min(score)+thold*range(score);
                    xy = xy(score<=t,:);
                    r = r(score<=t,:);

                    bbox = [bsxfun(@minus,xy,r), 2*r, 2*r];
                    
                    mask = roi(sub2ind(size(roi),xy(:,2),xy(:,1)));

                    centroids{ii} = xy(mask,:);
                    bboxes{ii} = bbox(mask,:);
                end
                
                figure(sum(mfilename+0));
                btui.utils.track(I,centroids,bboxes);
                
            else
                status('No detections loaded. Click "Load Detections" before starting tracking.');
            end
            
            this.state('idle');
            
        end
        function listenerTrackingDetections(this,~,~)
            % Update detections whenever it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            if ~this.DetectionCheckBox.Selected
                this.DetectionCheckBox.Selected = true;
            else
                this.showDetections();
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
        % Loading and displaying an image sequence
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
                
                % Add default optical flow vectors
                hold on;
                hquiver = quiver(haxes,0,0,0,0);
                hquiver.AutoScale = 'off';
                hquiver.Color = this.OpticalFlowTab.Color;
                hquiver.LineWidth = this.OpticalFlowTab.Linewidth;
                hold off;
                
                % Add default detections
                hold on;
                hpatch = circle(0,0,0);
                hpatch.FaceColor = this.TrackingTab.Color;
                hpatch.EdgeColor = max(0,this.TrackingTab.Color-0.2);
                hpatch.LineWidth = this.TrackingTab.Linewidth;
                hpatch.FaceAlpha = this.TrackingTab.Opacity;
                hold off;
                
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
                set(haxes,'Color',this.RoiTab.DefaultColor); %initialize overlay color by setting axes color
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
            this.state('selecting an image sequence to load');
            
            usercanceled = this.datalossdlg(); %check if user wants to proceed with data loss
            if ~usercanceled %user clicked yes
                
                this.ToolGroup.Title = this.AppName;
                
                switch location
                    case 'from file' %query user to select image sequence from file
                        
                        cwd = pwd; %get current working directory
                        
                        % Change to directory where data is stored. If the 
                        % user did not specify DataPath or if the value of 
                        % DataPath is invalid for the current machine, then
                        % look in the default directory for ISML demos.
                        if ~isempty(this.DataPath) && exist(this.DataPath,'dir')
                            cd(this.DataPath);
                        else
                            cd(fullfile(beadtracking.path,'resources','demos'));
                        end
                        
                        [filename,pathname] = uigetfile(...
                            {'*.jpg;*.tif;*.png;*.gif','All Image Files'; '*.*','All Files'},...
                            'Load Image Sequence From File');
                        
                        cd(cwd); %go back to 'current working directory'
                        
                        % If the user selected a file, load the image
                        % sequence. Otherwise, return an empty array.
                        if ~isempty(filename) && ~isequal(filename,0)
                            im = imframe(fullfile(pathname,filename),'all','class','uint8');
                        else
                            im = [];
                        end
                        
                    case 'from workspace' %query user to select image sequence from workspace
                        im = importdlg();
                        filename = []; %this is set to update figure name correctly
                end
                
                if ~isempty(im)
                    isvalidtype = btui.internal.MultipleObjectTrackingTool.isvalidimage(im);
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
                        this.initializeAppWithImage(im);
                        if ~isempty(filename)
                            this.ToolGroup.Title = sprintf('%s: %s',this.AppName,filename);
                        end
                    end
                else
                    this.state('waiting for user to load an image sequence');
                end
            else
                this.state('user canceled datalossdlg');
            end
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
        % ROI
        %******************************************************************
        function showRoi(this)
            % Show current region of interest.
            h = this.ImageHandle;
            if ~isempty(h)
                h.CDataMapping = 'scaled';
                h.AlphaData = this.RoiTab.AlphaData;
            end
        end
        function hideRoi(this)
            % Hide current region of interest.
            h = this.ImageHandle;
            if ~isempty(h)
                h.CDataMapping = 'scaled';
                h.AlphaData = ones(this.Backend.ImageSize);
            end
        end
        
        %******************************************************************
        % Optical Flow
        %******************************************************************
        function showOpticalFlow(this)
            % Show optical flow velocity vectors.
            
            X = this.OpticalFlowTab.QuiverInput;
            if isempty(X); return; end
            
            roi = this.RoiTab.Mask;
            mask = roi(sub2ind(size(roi),X(:,2),X(:,1)));
            X(~mask,:) = [];
            
            hquiver = this.OpticalFlowHandle;
            hquiver.XData = X(:,1);
            hquiver.YData = X(:,2);
            hquiver.UData = X(:,3);
            hquiver.VData = X(:,4);
        end
        function hideOpticalFlow(this)
            % Hide optical flow velocity vectors.
            hquiver = this.OpticalFlowHandle;
            hquiver.XData = 0;
            hquiver.YData = 0;
            hquiver.UData = 0;
            hquiver.VData = 0;
        end
        
        %******************************************************************
        % Detections
        %******************************************************************
        function showDetections(this)
            % Show detections.
            
            X = this.TrackingTab.Detections;
            if isempty(X); return; end
            X = X{this.VideoControlsSection.CurrentFrame};
            score = X(:,4);
            
            thold = min(score)+this.TrackingTab.Threshold*range(score);
            X = X(score<=thold,1:3);
            
            roi = this.RoiTab.Mask;
            mask = roi(sub2ind(size(roi),X(:,2),X(:,1)));
            X(~mask,:) = [];
            
            theta = (0:2:360)'*pi/180;
            x = bsxfun(@times,X(:,3)',cos(theta));
            x = bsxfun(@plus,x,X(:,1)');
            
            y = bsxfun(@times,X(:,3)',sin(theta));
            y = bsxfun(@plus,y,X(:,2)');

            v = [x(:),y(:)]; %vertices
            f = reshape(1:numel(x),[],size(X,1))'; %faces
            
            set(this.DetectionHandle,'Faces',f,'Vertices',v);
        end
        function hideDetections(this)
            % Hide detections.
            set(this.DetectionHandle,'Faces',1,'Vertices',[0 0]);
        end
        
        
        %******************************************************************
        % State management
        %******************************************************************
        function status(this,str)
            % Wrapper for gui.setStatusBarText
            gui.setStatusBarText(this.GroupName,str);
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
        function h = get.OpticalFlowHandle(this)
            h = findobj(this.Backend.hScrollPanel,'type','quiver');
        end
        function h = get.DetectionHandle(this)
            h = findobj(this.Backend.hScrollPanel,'type','patch');
        end
    end
    
    
    %======================================================================
    %
    % Static methods
    %
    %======================================================================
    methods (Static)
        function tf = isvalidimage(im)
            % Check if input image is valid.
            supportedClasses	= isa(im,'uint8') || isa(im,'uint16') || isa(im,'double');
            supportedAttributes	= isreal(im) && all(isfinite(im(:))) && ~issparse(im) && ndims(im)==4;
            
            tf = supportedClasses && supportedAttributes;
        end
    end
    
end

