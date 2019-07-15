classdef MultipleObjectTrackingTool < handle
%MULTIPLEOBJECTTRACKINGTOOL Track multiple objects in an image sequence.

%   Copyright 2016 Matthew R. Eicholtz
    
    properties
        % Main
        AppName = 'Multiple Object Tracker';
        GroupName
        ToolGroup
        
        % Tabs
        HomeTab
        RoiTab
        OpticalFlowTab
        
        % Sections
        FileSection
        VideoControlsSection
        ZoomPanSection
        OptionsSection
        
        MethodSection
        SettingsSection
        HornSchunckSection
        LucasKanadeSection
        
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
        
        UpdateOpticalFlowListener
        
        % Used to record segment/refine actions performed. This is needed
        % for generating code.
        EventLog
    end
    properties (Dependent=true, SetAccess=private)
        AxesHandle
        ImageHandle
        OpticalFlowHandle
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
        
        % OpticalFlow\Method
        MethodButton
        
        % OpticalFlow\Settings
        OpticalFlowColorLabel
        OpticalFlowColorButton
        OpticalFlowLinewidthLabel
        OpticalFlowLinewidthText
        OpticalFlowDecimationLabel
        OpticalFlowDecimationText
        OpticalFlowScaleLabel
        OpticalFlowScaleText
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
        LoadButtonIcon          = isml.gui.Icon.IMPORT_24;
        LoadButtonPopupIcon     = isml.gui.Icon.IMPORT_16;
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
        
        % Home\Options
        RoiCheckBoxStr                  = 'ROI';
        RoiCheckBoxToolTipText          = 'Show the selected region of interest';
        OpticalFlowCheckBoxStr        	= 'Optical Flow';
        OpticalFlowCheckBoxToolTipText  = 'Show optical flow velocity vectors on the image';
        DetectionCheckBoxStr            = 'Detection';
        DetectionCheckBoxToolTipText    = 'Show detected objects on the image';
        TrackingCheckBoxStr             = 'Tracking';
        TrackingCheckBoxToolTipText     = 'Show tracking results on the image';
        
        % OpticalFlow\Method
        MethodButtonPopupOption1Title   = 'None (Default)';
        MethodButtonPopupOption1Desc    = 'Do not compute optical flow';
        MethodButtonPopupOption2Title   = 'Horn-Schunck';
        MethodButtonPopupOption2Desc    = 'Global method for estimating optical flow that assumes brightness velocity varies smoothly almost everywhere in the image';
        MethodButtonPopupOption3Title   = 'Lucas-Kanade';
        MethodButtonPopupOption3Desc    = 'Local method for estimating optical flow that assumes constant flow in the neighborhood of a pixel';
        MethodButtonToolTipText         = 'Choose optical flow method';
        
        % OpticalFlow\Settings
        OpticalFlowColorLabelStr        = 'Color';
        OpticalFlowColorToolTipText     = 'Change color of velocity vectors';
        OpticalFlowLinewidthLabelStr    = 'Line width';
        OpticalFlowLinewidthToolTipText = 'Change thickness of velocity vectors';
        OpticalFlowDecimationLabelStr   = 'Decimation';
        OpticalFlowDecimationToolTipText= 'Change spacing of velocity vectors';
        OpticalFlowScaleLabelStr        = 'Scale';
        OpticalFlowScaleToolTipText     = 'Change size of velocity vectors';
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
       
        % OpticalFlow\Method
        MethodButtonDefault             = 'None';
        
        % OpticalFlow\Settings
        OpticalFlowColorDefault         = 'green';
        OpticalFlowLinewidthDefault     = '1';
        OpticalFlowDecimationDefault    = '10';
        OpticalFlowScaleDefault         = '10';
    end
    
    
    %======================================================================
    %
    % Public methods
    %
    %======================================================================
    methods
        function this = MultipleObjectTrackingTool(varargin)
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
                'Home',[],...
                'ROI',[],...
                'OpticalFlow',[]);
            this.SectionHandles = struct(...
                'File',[],...
                'VideoControls',[],...
                'ZoomPan',[],...
                'Options',[],...
                'ROI',[],...
                'Method',[],...
                'Settings',[],...
                'HornSchunck',[],...
                'LucasKanade',[]);
            
            % Add tabs to tool group
            this.HomeTab        = this.ToolGroup.addTab('HomeTab','Home');
            this.RoiTab         = isml.gui.RoiManager(this,this.ToolGroup); %attach RoiManager to corresponding tab
            this.OpticalFlowTab = this.ToolGroup.addTab('OpticalFlowTab','Optical Flow');
            
            % Add sections to each tab
            this.FileSection            = this.HomeTab.addSection('FileSection','File');
            this.VideoControlsSection   = isml.gui.VideoManager(this,this.HomeTab); %attach VideoManager to corresponding section
            this.ZoomPanSection         = isml.gui.ZoomPanManager(this,this.HomeTab); %attach ZoomPanManager to corresponding section
            this.OptionsSection         = this.HomeTab.addSection('OptionsSection','Options');
            
            this.MethodSection          = this.OpticalFlowTab.addSection('MethodSection','Method');
            this.SettingsSection      	= this.OpticalFlowTab.addSection('SettingsSection','Settings');
            this.HornSchunckSection   	= this.OpticalFlowTab.addSection('HornSchunckSection','Horn-Schunck');
            this.LucasKanadeSection   	= this.OpticalFlowTab.addSection('LucasKanadeSection','Lucas-Kanade');
            
            % Layout each section
            this.layoutFileSection();
            this.layoutOptionsSection();
            
            this.layoutMethodSection();
            this.layoutSettingsSection();
            this.layoutHornSchunckSection();
            this.layoutLucasKanadeSection();
            
            % Update section handles
            this.SectionHandles.VideoControls   = this.VideoControlsSection.Handles;
            this.SectionHandles.ZoomPan         = this.ZoomPanSection.Handles;
            this.SectionHandles.ROI             = this.RoiTab.Handles;
            
            % Update tab handles
            this.TabHandles.Home = [...
                this.SectionHandles.File,...
                this.SectionHandles.VideoControls,...
                this.SectionHandles.ZoomPan,...
                this.SectionHandles.Options];
            this.TabHandles.ROI = this.RoiTab.Handles.All;
            this.TabHandles.OpticalFlow = [...
                this.SectionHandles.Method,...
                this.SectionHandles.Settings,...
                this.SectionHandles.HornSchunck,...
                this.SectionHandles.LucasKanade];
            
            % Update all handles
            this.AllHandles = [...
                this.TabHandles.Home,...
                this.TabHandles.ROI,...
                this.TabHandles.OpticalFlow];
            
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
            
            % If image data was specified, load it into the app
            if exist('im','var')
                [this,im] = normdlg(this,im);
                this.initializeAppWithImage(im);
            end
        end
        function initializeAppWithImage(this,im)
            % Initialize tracking backend with image
            this.Backend = btui.internal.MultipleObjectTrackingBackend(im);
            
            % Create image display
            this.Backend.hfigure = createTrackingView(this);
            
            % Update ROI mask
            this.RoiTab.Mask = true(this.Backend.ImageSize);
            
            % Update controls after loading image
            this.state('image loaded'); %resets all controls and makes image editable
            
            % Update backend listeners
            this.UpdateOpticalFlowListener = event.proplistener(this.Backend,...
                this.Backend.findprop('OpticalFlow'),'PostSet',@this.listenerBackendOpticalFlow);
        end
        function state(this,str)
            % Enable/disable controls based on app state.
            if strcmp(str,'previous')
                str = this.PreviousState;
            end
            switch str
                case 'wait for response'
                    disable(this.AllHandles);
                    enable(this.SectionHandles.VideoControls); %allow video controls
                    enable(this.SectionHandles.ROI.Response); %wait for user response
                    
                case 'idle'
                    % This is the state in which an image is in view, so
                    % enable all image editing controls, but do not reset
                    % default values.
                    enable(this.TabHandles.Home);
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    disable(this.SectionHandles.ROI.Response);
                    
                case 'image loaded'
                    % Enable relevant controls
                    enable(this.TabHandles.Home);
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    disable(this.SectionHandles.ROI.Response);
                    
                    % Return to default parameter values
                    this.VideoControlsSection.setNumberOfFrames(this.Backend.NumFrames);
                    this.VideoControlsSection.reset();
                    this.ZoomPanSection.reset();
                    this.RoiTab.reset();
                    
                    % Update PreviousState
                    this.PreviousState = str;
                    
                case 'initial'
                    disable(this.AllHandles);
                    enable(this.SectionHandles.File); %allow user to load an image sequence
                    
                    this.VideoControlsSection.reset();
                    this.ZoomPanSection.reset();
                    this.RoiTab.reset();
                    
                case 'roi loaded'
                    enable(this.TabHandles.Home);
                    enable(this.TabHandles.ROI);
                    enable(this.TabHandles.OpticalFlow);
                    disable(this.SectionHandles.ROI.Response);
                    
                case 'disable all controls'
                    disable(this.AllHandles);
                    
                case 'enable all usable controls'
                    enable(this.AllHandles);
                    disable(this.SectionHandles.ROI.Response);
                    
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
        function layoutMethodSection(this)
            % Create button for choosing a method
            this.MethodButton = toolpack.component.TSDropDownButton(this.MethodButtonDefault);
            this.MethodButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.MethodButton,this.MethodButtonToolTipText);
            
            % Add popup menu to button
            items(1) = struct(...
                'Title',this.MethodButtonPopupOption1Title,...
                'Description',this.MethodButtonPopupOption1Desc,...
                'Icon',[],...
                'Header',false);
            items(2) = struct(...
                'Title',this.MethodButtonPopupOption2Title,...
                'Description',this.MethodButtonPopupOption2Desc,...
                'Icon',[],...
                'Header',false);
            items(3) = struct(...
                'Title',this.MethodButtonPopupOption3Title,...
                'Description',this.MethodButtonPopupOption3Desc,...
                'Icon',[],...
                'Header',false);
            this.MethodButton.Popup = toolpack.component.TSDropDownPopup(items,'single_line_description');
            addlistener(this.MethodButton.Popup,'ListItemSelected',@this.listenerMethodButton);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('50dlu','f:p'); %(columns,rows)
            panel.add(this.MethodButton,'xy(1,1)');
            
            % Add panel to section
            this.MethodSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.Method = {this.MethodButton};
        end
        function layoutSettingsSection(this)
            % Create button to set optical flow color
            % Note: there is no MCOS interface to set the icon of a TSButton directly from a uint8 buffer.
            this.OpticalFlowColorLabel = toolpack.component.TSLabel(this.OpticalFlowColorLabelStr);
            this.OpticalFlowColorButton = toolpack.component.TSButton();
            isml.gui.setTSButtonIconFromImage(this.OpticalFlowColorButton,makeicon(16,16,this.OpticalFlowColorDefault));
            iptui.internal.utilities.setToolTipText(this.OpticalFlowColorButton,this.OpticalFlowColorToolTipText);
            addlistener(this.OpticalFlowColorButton,'ActionPerformed',@this.listenerOpticalFlowColor);
            
            % Create widgets for optical flow line width
            this.OpticalFlowLinewidthLabel = toolpack.component.TSLabel(this.OpticalFlowLinewidthLabelStr);
            this.OpticalFlowLinewidthText = toolpack.component.TSTextField(this.OpticalFlowLinewidthDefault,2);
            iptui.internal.utilities.setToolTipText(this.OpticalFlowLinewidthText,this.OpticalFlowLinewidthToolTipText);
            addlistener(this.OpticalFlowLinewidthText,'TextEdited',@this.listenerOpticalFlowLinewidth);
            
            % Create widgets for optical flow decimation
            this.OpticalFlowDecimationLabel = toolpack.component.TSLabel(this.OpticalFlowDecimationLabelStr);
            this.OpticalFlowDecimationText = toolpack.component.TSTextField(this.OpticalFlowDecimationDefault,2);
            iptui.internal.utilities.setToolTipText(this.OpticalFlowDecimationText,this.OpticalFlowDecimationToolTipText);
            addlistener(this.OpticalFlowDecimationText,'TextEdited',@this.listenerOpticalFlowDecimation);
            
            % Create widgets for optical flow scale
            this.OpticalFlowScaleLabel = toolpack.component.TSLabel(this.OpticalFlowScaleLabelStr);
            this.OpticalFlowScaleText = toolpack.component.TSTextField(this.OpticalFlowScaleDefault,2);
            iptui.internal.utilities.setToolTipText(this.OpticalFlowScaleText,this.OpticalFlowScaleToolTipText);
            addlistener(this.OpticalFlowScaleText,'TextEdited',@this.listenerOpticalFlowScale);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('3dlu,r:p,3dlu,f:p,6dlu,r:p,3dlu,f:p,3dlu','8dlu,14dlu,1dlu,14dlu,f:p:g'); %(columns,rows)
            panel.add(this.OpticalFlowColorLabel,       'xy(2,2)');
            panel.add(this.OpticalFlowColorButton,      'xy(4,2)');
            panel.add(this.OpticalFlowLinewidthLabel,   'xy(2,4)');
            panel.add(this.OpticalFlowLinewidthText,    'xy(4,4)');
            panel.add(this.OpticalFlowDecimationLabel,  'xy(6,2)');
            panel.add(this.OpticalFlowDecimationText,   'xy(8,2)');
            panel.add(this.OpticalFlowScaleLabel,       'xy(6,4)');
            panel.add(this.OpticalFlowScaleText,        'xy(8,4)');
            
            % Add panel to section
            this.SettingsSection.add(panel);
            
            % Save objects to handles structure
            this.SectionHandles.Settings = {...
                this.OpticalFlowColorLabel,...
                this.OpticalFlowColorButton,...
                this.OpticalFlowLinewidthLabel,...
                this.OpticalFlowLinewidthText,...
                this.OpticalFlowDecimationLabel,...
                this.OpticalFlowDecimationText,...
                this.OpticalFlowScaleLabel,...
                this.OpticalFlowScaleText};
        end
        function layoutHornSchunckSection(this)
            
        end
        function layoutLucasKanadeSection(this)
            
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
        % VideoManager
        %******************************************************************
        function listenerVideoCurrentFrame(this,~,~)
            % Update graphics in app when CurrentFrame is modified.
            if ~isvalid(this); return; end %return if app is closed

            ind = this.VideoControlsSection.CurrentFrame;
            
            % Update image
            himage = this.ImageHandle;
            if isvalid(himage)
                himage.CData = this.Backend.ImageSequence(:,:,:,ind);
                himage.CDataMapping = 'scaled';
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
        function showRoi(this)
            % Show current region of interest.
            this.ImageHandle.CDataMapping = 'scaled';
            this.ImageHandle.AlphaData = this.RoiTab.AlphaData;
        end
        function hideRoi(this)
            % Hide current region of interest.
            this.ImageHandle.CDataMapping = 'scaled';
            this.ImageHandle.AlphaData = ones(this.Backend.ImageSize);
        end
        
        %******************************************************************
        % Backend
        %******************************************************************
        function listenerBackendCurrentFrame(this,obj,evt)
            % Update graphics in app when backend CurrentFrame is modified.
            if ~isvalid(this); return; end %return if app is closed

            ind = this.Backend.CurrentFrame;
            
            % Update image
            himage = this.ImageHandle;
            if isvalid(himage)
                himage.CData = this.Backend.CurrentImage;
                himage.CDataMapping = 'scaled';
            end
            
            % Update toolstrip controls
            this.FrameSlider.Value = ind;
            this.CurrentFrameText.Text = num2str(ind);
            
            % Update optical flow
            this.Backend.updateOpticalFlow();
        end
        function listenerBackendOpticalFlow(this,~,~)
            % Show optical flow whenever it is modified.
            if ~isvalid(this); return; end %return if app is closed
            
            if this.OpticalFlowCheckBox.Selected
                this.showOpticalFlow();
            else
                this.hideOpticalFlow();
            end
        end
        
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
                this.showOpticalFlow();
            else
                this.hideOpticalFlow();
            end
        end
        function listenerDetectionCheckBox(this,obj,evt)
            % Overlay the detected objects on the image.
            
        end
        function listenerTrackingCheckBox(this,obj,evt)
            % Overlay the tracked objects on the image.
            
        end
        
        %******************************************************************
        % OpticalFlow\Method
        %******************************************************************
        function listenerMethodButton(this,obj,~)
            this.status('');
            switch obj.SelectedIndex
                case 1
                    this.Backend.OpticalFlowAlg = 'none';
                    this.MethodButton.Text = this.MethodButtonDefault;
                    this.OpticalFlowCheckBox.Selected = false;
                    disable(this.SectionHandles.Settings);
                case 2
                    this.Backend.OpticalFlowAlg = 'horn-schunck';
                    this.MethodButton.Text = this.MethodButtonPopupOption2Title;
                    this.OpticalFlowCheckBox.Selected = true;
                    this.showOpticalFlow();
                    enable(this.SectionHandles.Settings);
                case 3
                    this.Backend.OpticalFlowAlg = 'lucas-kanade';
                    this.MethodButton.Text = this.MethodButtonPopupOption3Title;
                    this.OpticalFlowCheckBox.Selected = true;
                    this.showOpticalFlow();
                    enable(this.SectionHandles.Settings);
            end
        end
        
        %******************************************************************
        % OpticalFlow\Settings
        %******************************************************************
        function listenerOpticalFlowColor(this,obj,~)
            % Query user to select new color
            clr = uisetcolor(this.OpticalFlowHandle.Color,'Select Optical Flow Color');

            % Update icon (unless user canceled color dialog box)
            if ~isequal(clr,0)
                isml.gui.setTSButtonIconFromImage(obj,makeicon(16,16,clr));
                this.OpticalFlowHandle.Color = clr;
                this.showOpticalFlow();
            end
        end
        function listenerOpticalFlowLinewidth(this,obj,evt)
            % Update line width of optical flow vectors.
            x = str2double(obj.Text); %index of current frame
            if isscalar(x) && isfinite(x) && x>0
                this.OpticalFlowHandle.LineWidth = x;
                this.showOpticalFlow();
            else %reset to previous value
                obj.Text = evt.EventData.oldValue;
            end
        end
        function listenerOpticalFlowDecimation(this,obj,evt)
            % Update decimation of optical flow vectors.
            x = str2double(obj.Text); %index of current frame
            if isscalar(x) && isfinite(x) && x>0 && x==floor(x)
                this.Backend.OpticalFlowDecimation = x;
                this.showOpticalFlow();
            else %reset to previous value
                obj.Text = evt.EventData.oldValue;
            end
        end
        function listenerOpticalFlowScale(this,obj,evt)
            % Update scale of optical flow vectors.
            x = str2double(obj.Text); %index of current frame
            if isscalar(x) && isfinite(x) && x>0 && x==floor(x)
                this.Backend.OpticalFlowScale = x;
                this.showOpticalFlow();
            else %reset to previous value
                obj.Text = evt.EventData.oldValue;
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
                
                % Add default optical flow vectors
                hold on;
                hquiver = quiver(haxes,0,0,0,0);
                hquiver.AutoScale = 'off';
                hquiver.Color = this.OpticalFlowColorDefault;
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
        % Optical Flow
        %******************************************************************
        function showOpticalFlow(this)
            % Show optical flow velocity vectors.
            X = this.Backend.QuiverInput;
            
            this.OpticalFlowHandle.XData = X(:,1);
            this.OpticalFlowHandle.YData = X(:,2);
            this.OpticalFlowHandle.UData = X(:,3);
            this.OpticalFlowHandle.VData = X(:,4);
        end
        function hideOpticalFlow(this)
            % Hide optical flow velocity vectors.
            this.OpticalFlowHandle.XData = 0;
            this.OpticalFlowHandle.YData = 0;
            this.OpticalFlowHandle.UData = 0;
            this.OpticalFlowHandle.VData = 0;
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

