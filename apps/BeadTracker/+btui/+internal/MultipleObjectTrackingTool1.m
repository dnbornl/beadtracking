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
        ROITab
        OpticalFlowTab
        
        % Sections
        FileSection
        VideoControlsSection
        ViewSection
        OptionsSection
        
        ROIFileSection
        ROIDrawSection
        ROISettingsSection
        ROIResponseSection
        
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
        
        % We cache listeners to state changed on buttons so that we can
        % disable/enable button listeners when a new image is loaded and we
        % restore the button states to an initialized state.
        FrameSliderListener
        ROIShowBinaryButtonListener
        ROIOpacitySliderListener
        ROIThicknessSliderListener
        
        % Cache knowledge of whether we normalized double input data so
        % that we can have thresholds in "generate function" context match
        % image data. Do the same for massaging of image data to handle
        % Nans and Infs appropriately.
        IsDataNormalized
        IsInfNanRemoved
        
        % Flag to notify play button about intention to stop playing.
        ContinuePlayingFlag
        
        % Flag to cache whether RGB image was loaded into App.
        wasRGB
    end
    properties (Access=private)
        % Used to react to changes in Backend object to 
        % update graphics appropriately.
        UpdateCurrentFrameListener
        UpdateROIListener
        UpdateOpticalFlowListener
        
        UpdateIterationListener
        
        % ROI drawing tools
        RectangleContainer
        PolygonContainer
        FreehandContainer
    end
    properties (Access=private)
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
        
        % Home\Video Controls
        CurrentFrameLabel
        CurrentFrameText
        CurrentFrameUnits
        FrameRateLabel
        FrameRateText
        FrameRateUnits
        FOILabel
        FOILabel2
        StartFrameText
        EndFrameText
        PrevFrameButton
        PlayButton
        NextFrameButton
        FrameSlider
        
        % Home\View
        ZoomInButton
        ZoomOutButton
        PanButton
        
        % Home\Options
        ROICheckBox
        OpticalFlowCheckBox
        DetectionCheckBox
        TrackingCheckBox
        
        % ROI\File
        ROILoadButton
        ResetButton
        
        % ROI\Settings
        ROIColorLabel
        ROIColorButton
        ROIOpacityLabel
        ROIOpacitySlider
        ROIThicknessLabel
        ROIThicknessSlider
        ROIShowBinaryButton
        
        % ROI\Draw
        DrawRectangleButton
        DrawPolygonButton
        DrawFreehandButton
        
        % ROI\Response
        OKButton
        CancelButton
        
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
        
        % OpticalFlow\HornSchunck
        
        
        % OpticalFlow\LucasKanade
        
        
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
        
        % Home\Video Controls
        PlayButtonIcon          = isml.gui.Icon.PLAY_16;
        PauseButtonIcon         = isml.gui.Icon.PAUSE_16;
        PrevFrameButtonIcon     = isml.gui.Icon.PREV_16;
        NextFrameButtonIcon     = isml.gui.Icon.NEXT_16;
        
        % Home\View
        ZoomInButtonIcon        = isml.gui.Icon.ZOOM_IN_16;
        ZoomOutButtonIcon       = isml.gui.Icon.ZOOM_OUT_16;
        PanButtonIcon           = isml.gui.Icon.PAN_16;
        
        % ROI\File
        ROILoadButtonIcon       = isml.gui.Icon.IMPORT_24;
        ROILoadButtonPopupIcon  = isml.gui.Icon.IMPORT_16;
        ResetButtonIcon         = isml.gui.Icon.UNDO_24;
        
        % ROI\Settings
        ROIShowBinaryButtonIcon = isml.gui.Icon.SHOWBINARY_24;
        
        % ROI\Draw
        DrawRectangleButtonIcon = isml.gui.Icon.RECTANGLE_16;
        DrawPolygonButtonIcon   = isml.gui.Icon.POLYGON_16;
        DrawFreehandButtonIcon  = isml.gui.Icon.FREEHAND_16;
        
        % ROI\Response
        OKButtonIcon            = isml.gui.Icon.CONFIRM_24;
        CancelButtonIcon        = isml.gui.Icon.CLOSE_24;
        
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
        
        % Home\Video Controls
        CurrentFrameLabelStr            = 'Current frame';
        CurrentFrameToolTipText         = 'Index of the currently visible frame';
        FrameRateLabelStr               = 'Frame rate';
        FrameRateToolTipText            = 'Frame rate of video playback';
        FrameRateUnitsStr               = 'fps';
        FOILabelStr                     = 'Frames of interest (FOI)';
        StartFrameTextToolTipText       = 'Modify starting frame';
        EndFrameTextToolTipText         = 'Modify ending frame';
        PlayButtonStr                   = '';
        PlayButtonToolTipText           = 'Play';
        PauseButtonToolTipText          = 'Pause';
        PrevFrameButtonStr              = '';
        PrevFrameButtonToolTipText      = 'Go to previous frame';
        NextFrameButtonStr              = '';
        NextFrameButtonToolTipText      = 'Go to next frame';
        FrameSliderToolTipText          = 'Change frames';
        
        % Home\View
        ZoomInButtonStr                 = 'Zoom in';
        ZoomInButtonToolTipText         = 'Zoom in';
        ZoomOutButtonStr                = 'Zoom out';
        ZoomOutButtonToolTipText        = 'Zoom out';
        PanButtonStr                    = 'Pan';
        PanButtonToolTipText            = 'Pan';
        
        % Home\Options
        ROICheckBoxStr                  = 'ROI';
        ROICheckBoxToolTipText          = 'Show the selected region of interest';
        OpticalFlowCheckBoxStr        	= 'Optical Flow';
        OpticalFlowCheckBoxToolTipText  = 'Show optical flow velocity vectors on the image';
        DetectionCheckBoxStr            = 'Detection';
        DetectionCheckBoxToolTipText    = 'Show detected objects on the image';
        TrackingCheckBoxStr             = 'Tracking';
        TrackingCheckBoxToolTipText     = 'Show tracking results on the image';
        
        % ROI\File
        ROILoadButtonStr                = sprintf('Load ROI\nMask');
        ROILoadButtonToolTipText        = 'Load ROI mask from workspace or file';
        ROILoadButtonStatusBarText      = 'Loading ROI mask...';
        ROILoadButtonPopupOption1       = 'Load ROI Mask From File';
        ROILoadButtonPopupOption2       = 'Load ROI Mask From Workspace';
        InvalidMaskDlgMessage           = 'ROI mask must be a 2-D logical image of the same size as the input image. Please choose a valid mask.';
        InvalidMaskDlgTitle             = 'Invalid ROI Mask';
        ResetButtonStr                  = 'Reset';
        ResetButtonToolTipText          = 'Revert to default region of interest';
        ResetButtonStatusBarText        = 'Restoring default region of interest...';
        
        % ROI\Settings
        ROIColorLabelStr                = 'Color';
        ROIColorButtonToolTipText       = 'Change region-of-interest color';
        ROIOpacityLabelStr              = 'Opacity';
        ROIOpacitySliderToolTipText     = 'Adjust region-of-interest opacity';
        ROIShowBinaryButtonStr          = sprintf('Show\nBinary');
        ROIShowBinaryButtonToolTipText  = 'View binary mask';
        ROIThicknessLabelStr          	= 'Thickness';
        ROIThicknessSliderToolTipText 	= 'Adjust region-of-interest boundary thickness';
    
        % ROI\Draw
        DrawRectangleButtonStr        	= 'Draw Rectangle';
        DrawRectangleButtonToolTipText 	= 'Initialize region of interest by drawing a rectangle';
        DrawRectangleButtonStatusBarText= 'Draw one or more rectangles on the image. Click OK or Cancel when finished.';
        DrawPolygonButtonStr          	= 'Draw Polygon';
        DrawPolygonButtonToolTipText   	= 'Initialize region of interest by drawing a polygon';
        DrawPolygonButtonStatusBarText 	= 'Draw one or more polygons on the image. Click OK or Cancel when finished.';
        DrawFreehandButtonStr         	= 'Draw Freehand';
        DrawFreehandButtonToolTipText  	= 'Initialize region of interest by drawing a freehand contour';
        DrawFreehandButtonStatusBarText	= 'Draw one or more freehand contours on the image. Click OK or Cancel when finished.';
        
        % ROI\Response
        OKButtonStr                     = 'OK';
        OKButtonToolTipText             = '';
        CancelButtonStr                 = 'Cancel';
        CancelButtonToolTipText   	 	= '';
        
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
        
        % OpticalFlow\HornSchunck
        
        % OpticalFlow\LucasKanade
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
        
        % Home\Video Controls
        CurrentFrameTextDefault         = '1';
        CurrentFrameUnitsDefault        = '/ ?';
        FrameRateTextDefault            = '30';
        StartFrameTextDefault           = '1';
        EndFrameTextDefault             = '?';
        FrameSliderDefault              = 1;
        FrameSliderMinimumDefault       = 1;
        
        % Home\Options
        ROICheckBoxDefault              = false;
        OpticalFlowCheckBoxDefault      = false;
        DetectionCheckBoxDefault        = false;
        TrackingCheckBoxDefault         = false;
        
        % ROI\Settings
        ROIColorDefault                 = 'red';
        ROIOpacitySliderDefault         = 70;
        ROIThicknessSliderDefault       = 1;
       
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
                'View',[],...
                'Options',[],...
                'ROIFile',[],...
                'ROISettings',[],...
                'ROIDraw',[],...
                'ROIResponse',[],...
                'Method',[],...
                'Settings',[],...
                'HornSchunck',[],...
                'LucasKanade',[]);
            
            % Add tabs to tool group
            this.HomeTab        = this.ToolGroup.addTab('HomeTab','Home');
            this.ROITab         = this.ToolGroup.addTab('ROITab','ROI');
            this.OpticalFlowTab = this.ToolGroup.addTab('OpticalFlowTab','Optical Flow');
            
            % Add sections to each tab
            this.FileSection            = this.HomeTab.addSection('FileSection','File');
            this.VideoControlsSection   = this.HomeTab.addSection('VideoControlsSection','Video Controls');
            this.ViewSection            = this.HomeTab.addSection('ViewSection','View');
            this.OptionsSection         = this.HomeTab.addSection('OptionsSection','Options');
            
            this.ROIFileSection         = this.ROITab.addSection('ROIFileSection','File');
            this.ROIDrawSection       	= this.ROITab.addSection('ROIDrawSection','Draw');
            this.ROISettingsSection   	= this.ROITab.addSection('ROISettingsSection','Settings');
            this.ROIResponseSection     = this.ROITab.addSection('ROIResponseSection','Response');
            
            this.MethodSection          = this.OpticalFlowTab.addSection('MethodSection','Method');
            this.SettingsSection      	= this.OpticalFlowTab.addSection('SettingsSection','Settings');
            this.HornSchunckSection   	= this.OpticalFlowTab.addSection('HornSchunckSection','Horn-Schunck');
            this.LucasKanadeSection   	= this.OpticalFlowTab.addSection('LucasKanadeSection','Lucas-Kanade');
            
            % Layout each section
            this.layoutFileSection();
            this.layoutVideoControlsSection();
            this.layoutViewSection();
            this.layoutOptionsSection();
            
            this.layoutROIFileSection();
            this.layoutROIDrawSection();
            this.layoutROISettingsSection();
            this.layoutROIResponseSection();
            
            this.layoutMethodSection();
            this.layoutSettingsSection();
            this.layoutHornSchunckSection();
            this.layoutLucasKanadeSection();
            
            % Update tab handles
            this.TabHandles.Home = [...
                this.SectionHandles.File,...
                this.SectionHandles.VideoControls,...
                this.SectionHandles.View,...
                this.SectionHandles.Options];
            this.TabHandles.ROI = [...
                this.SectionHandles.ROIFile,...
                this.SectionHandles.ROIDraw,...
                this.SectionHandles.ROISettings,...
                this.SectionHandles.ROIResponse];
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
            
            % Update backend listeners
            this.UpdateCurrentFrameListener = event.proplistener(this.Backend,...
                this.Backend.findprop('CurrentFrame'),'PostSet',@this.listenerBackendCurrentFrame);
            this.UpdateROIListener = event.proplistener(this.Backend,...
                this.Backend.findprop('ROI'),'PostSet',@this.listenerBackendROI);
            this.UpdateOpticalFlowListener = event.proplistener(this.Backend,...
                this.Backend.findprop('OpticalFlow'),'PostSet',@this.listenerBackendOpticalFlow);
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
        function layoutVideoControlsSection(this)
            % Create widgets for current frame editing and display
            this.CurrentFrameLabel = toolpack.component.TSLabel(this.CurrentFrameLabelStr);
            this.CurrentFrameText = toolpack.component.TSTextField(this.CurrentFrameTextDefault,3);
            this.CurrentFrameUnits = toolpack.component.TSLabel(this.CurrentFrameUnitsDefault);
            iptui.internal.utilities.setToolTipText(this.CurrentFrameText,this.CurrentFrameToolTipText);
            addlistener(this.CurrentFrameText,'TextEdited',@this.listenerCurrentFrameText);
            
            % Create widgets for frame rate editing and display
            this.FrameRateLabel = toolpack.component.TSLabel(this.FrameRateLabelStr);
            this.FrameRateText = toolpack.component.TSTextField(this.FrameRateTextDefault,3);
            this.FrameRateUnits = toolpack.component.TSLabel(this.FrameRateUnitsStr);
            iptui.internal.utilities.setToolTipText(this.FrameRateText,this.FrameRateToolTipText);
            addlistener(this.FrameRateText,'TextEdited',@this.listenerFrameRateText);
            
            % Create widgets for selecting frames of interest (FOI)
            this.FOILabel = toolpack.component.TSLabel(this.FOILabelStr);
            
            this.StartFrameText = toolpack.component.TSTextField(this.StartFrameTextDefault,3);
            iptui.internal.utilities.setToolTipText(this.StartFrameText,this.StartFrameTextToolTipText);
            addlistener(this.StartFrameText,'TextEdited',@this.listenerStartFrameText);
            
            this.FOILabel2 = toolpack.component.TSLabel('to');
            
            this.EndFrameText = toolpack.component.TSTextField(this.EndFrameTextDefault,3);
            iptui.internal.utilities.setToolTipText(this.EndFrameText,this.EndFrameTextToolTipText);
            addlistener(this.EndFrameText,'TextEdited',@this.listenerEndFrameText);
            
            % Pack CurrentFrame and FrameRate widgets into subpanel
            subpanel1 = toolpack.component.TSPanel(...
                '3dlu,r:p,3dlu,l:p,2dlu,f:p,10dlu,f:p,9dlu,f:p,3dlu,f:p,3dlu,f:p,10dlu',...
                '3dlu,f:p,3dlu,f:p');
            subpanel1.add(this.CurrentFrameLabel,   'xy(2,2)');
            subpanel1.add(this.CurrentFrameText,    'xy(4,2,''l,c'')');
            subpanel1.add(this.CurrentFrameUnits,   'xy(6,2)');
            subpanel1.add(this.FrameRateLabel,      'xy(2,4)');
            subpanel1.add(this.FrameRateText,       'xy(4,4,''l,c'')');
            subpanel1.add(this.FrameRateUnits,      'xy(6,4)');
            subpanel1.add(this.FOILabel,            'xywh(8,2,8,1)');
            subpanel1.add(this.StartFrameText,      'xy(10,4,''l,c'')');
            subpanel1.add(this.FOILabel2,           'xy(12,4)');
            subpanel1.add(this.EndFrameText,        'xy(14,4,''l,c'')');
            
            % Create button for playing/pausing video
            this.PlayButton = toolpack.component.TSButton(this.PlayButtonStr,this.PlayButtonIcon);
            this.PlayButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.PlayButton,this.PlayButtonToolTipText);
            addlistener(this.PlayButton,'ActionPerformed',@this.listenerPlayButton);
            addlistener(this.PlayButton,'ActionPerformed',@this.listenerPlayButtonState);
            
            % Create buttons for moving to previous/next frame
            this.PrevFrameButton = toolpack.component.TSButton(this.PrevFrameButtonStr,this.PrevFrameButtonIcon);
            this.PrevFrameButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.PrevFrameButton,this.PrevFrameButtonToolTipText);
            addlistener(this.PrevFrameButton,'ActionPerformed',@this.listenerPrevFrameButton);
            
            this.NextFrameButton = toolpack.component.TSButton(this.NextFrameButtonStr,this.NextFrameButtonIcon);
            this.NextFrameButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.NextFrameButton,this.NextFrameButtonToolTipText);
            addlistener(this.NextFrameButton,'ActionPerformed',@this.listenerNextFrameButton);
            
            % Create slider for frame control
            this.FrameSlider = toolpack.component.TSSlider(1,100,this.FrameSliderDefault);
            this.FrameSlider.MinorTickSpacing = 1;
            iptui.internal.utilities.setToolTipText(this.FrameSlider,this.FrameSliderToolTipText);
            addlistener(this.FrameSlider,'StateChanged',@this.listenerFrameSlider);
            
            % Pack PlayButton, FrameSlider, PrevFrameButton, and NextFrameButton widgets into subpanel
            subpanel2 = toolpack.component.TSPanel('1dlu,f:p,f:p,f:p,1dlu,f:p','f:p:g'); %(columns,rows)
            subpanel2.add(this.PrevFrameButton, 'xy(2,1)');
            subpanel2.add(this.PlayButton,      'xy(3,1)');
            subpanel2.add(this.NextFrameButton, 'xy(4,1)');
            subpanel2.add(this.FrameSlider,     'xy(6,1)');
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g,2dlu,f:p:g'); %(columns,rows)
            panel.add(subpanel1,'xy(1,1)');
            panel.add(subpanel2,'xy(1,3)');
            
            % Add panel to section
            this.VideoControlsSection.add(panel);
            
            % Save buttons to handles structure
            this.SectionHandles.VideoControls = {...
                this.CurrentFrameLabel,...
                this.CurrentFrameText,...
                this.CurrentFrameUnits,...
                this.FrameRateLabel,...
                this.FrameRateText,...
                this.FrameRateUnits,...
                this.FOILabel,...
                this.StartFrameText,...
                this.FOILabel2,...
                this.EndFrameText,...
                this.PrevFrameButton,...
                this.PlayButton,...
                this.NextFrameButton,...
                this.FrameSlider};
        end
        function layoutViewSection(this)
            % Create buttons for zooming in/out and panning
            this.ZoomInButton = toolpack.component.TSToggleButton(this.ZoomInButtonStr,this.ZoomInButtonIcon);
            this.ZoomInButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.ZoomInButton,this.ZoomInButtonToolTipText);
            addlistener(this.ZoomInButton,'ItemStateChanged',@this.listenerZoomInButton);
            
            this.ZoomOutButton = toolpack.component.TSToggleButton(this.ZoomOutButtonStr,this.ZoomOutButtonIcon);
            this.ZoomOutButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.ZoomOutButton,this.ZoomOutButtonToolTipText);
            addlistener(this.ZoomOutButton,'ItemStateChanged',@this.listenerZoomOutButton);
            
            this.PanButton = toolpack.component.TSToggleButton(this.PanButtonStr,this.PanButtonIcon);
            this.PanButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.PanButton,this.PanButtonToolTipText);
            addlistener(this.PanButton,'ItemStateChanged',@this.listenerPanButton);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g,f:p:g,f:p:g'); %(columns,rows)
            panel.add(this.ZoomInButton,    'xy(1,1)');
            panel.add(this.ZoomOutButton,   'xy(1,2)');
            panel.add(this.PanButton,       'xy(1,3)');
            
            % Add panel to section
            this.ViewSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.View = {...
                this.ZoomInButton,...
                this.ZoomOutButton,...
                this.PanButton};
        end
        function layoutOptionsSection(this)
            % Create checkboxes for each option
            this.ROICheckBox = toolpack.component.TSCheckBox(this.ROICheckBoxStr,this.ROICheckBoxDefault);
            iptui.internal.utilities.setToolTipText(this.ROICheckBox,this.ROICheckBoxToolTipText);
            addlistener(this.ROICheckBox,'ItemStateChanged',@this.listenerROICheckBox);
            
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
            panel.add(this.ROICheckBox,         'xy(1,1)');
            panel.add(this.OpticalFlowCheckBox, 'xy(1,2)');
            panel.add(this.DetectionCheckBox,   'xy(1,3)');
            panel.add(this.TrackingCheckBox,    'xy(1,4)');
            
            % Add panel to section
            this.OptionsSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.Options = {...
                this.ROICheckBox,...
                this.OpticalFlowCheckBox,...
                this.DetectionCheckBox,...
                this.TrackingCheckBox};
        end
        function layoutROIFileSection(this)
            % Create button for loading an image sequence
            this.ROILoadButton = toolpack.component.TSSplitButton(this.ROILoadButtonStr,this.ROILoadButtonIcon);
            this.ROILoadButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.ROILoadButton,this.ROILoadButtonToolTipText);
            addlistener(this.ROILoadButton,'ActionPerformed',@this.listenerROILoadButton);
            
            % Add popup menu to load button
            items(1) = struct(...
                'Title',this.ROILoadButtonPopupOption1,...
                'Description','',...
                'Icon',this.ROILoadButtonPopupIcon,...
                'Help',[],...
                'Header',false);
            items(2) = struct(...
                'Title',this.ROILoadButtonPopupOption2,...
                'Description','',...
                'Icon',this.ROILoadButtonPopupIcon,...
                'Help',[],...
                'Header',false);
            this.ROILoadButton.Popup = toolpack.component.TSDropDownPopup(items,'icon_text');
            addlistener(this.ROILoadButton.Popup,'ListItemSelected',@this.listenerROILoadButtonPopup);
            
            % Create button for restoring default ROI
            this.ResetButton = toolpack.component.TSButton(this.ResetButtonStr,this.ResetButtonIcon);
            this.ResetButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.ResetButton,this.ResetButtonToolTipText);
            addlistener(this.ResetButton,'ActionPerformed',@this.listenerResetButton);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,3dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(this.ROILoadButton,'xy(1,1)');
            panel.add(this.ResetButton,'xy(3,1)');
            
            % Add panel to section
            this.ROIFileSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.ROIFile = {...
                this.ROILoadButton,...
                this.ResetButton};
        end
        function layoutROISettingsSection(this)
            % Create button to set object color
            % Note: there is no MCOS interface to set the icon of a TSButton directly from a uint8 buffer.
            this.ROIColorLabel = toolpack.component.TSLabel(this.ROIColorLabelStr);
            this.ROIColorButton = toolpack.component.TSButton();
            this.setTSButtonIconFromImage(this.ROIColorButton,btui.utils.makeicon(16,16,this.ROIColorDefault));
            iptui.internal.utilities.setToolTipText(this.ROIColorButton,this.ROIColorButtonToolTipText);
            addlistener(this.ROIColorButton,'ActionPerformed',@this.listenerROIColorButton);
            
            % Create slider for ROI opacity
            this.ROIOpacityLabel = toolpack.component.TSLabel(this.ROIOpacityLabelStr);
            this.ROIOpacitySlider = toolpack.component.TSSlider(0,100,this.ROIOpacitySliderDefault);
            this.ROIOpacitySlider.MinorTickSpacing = 0.1;
            iptui.internal.utilities.setToolTipText(this.ROIOpacitySlider,this.ROIOpacitySliderToolTipText);
            this.ROIOpacitySliderListener = addlistener(this.ROIOpacitySlider,'StateChanged',@this.listenerROIOpacitySlider);

            % Create slider for ROI thickness
            this.ROIThicknessLabel = toolpack.component.TSLabel(this.ROIThicknessLabelStr);
            this.ROIThicknessSlider = toolpack.component.TSSlider(0,10,this.ROIThicknessSliderDefault);
            this.ROIThicknessSlider.MinorTickSpacing = 1;
            iptui.internal.utilities.setToolTipText(this.ROIThicknessSlider,this.ROIThicknessSliderToolTipText);
            this.ROIThicknessSliderListener = addlistener(this.ROIThicknessSlider,'StateChanged',@this.listenerROIThicknessSlider);
            
            % Create toggle button to show binary mask
            this.ROIShowBinaryButton = toolpack.component.TSToggleButton(this.ROIShowBinaryButtonStr,this.ROIShowBinaryButtonIcon);
            this.ROIShowBinaryButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.ROIShowBinaryButton,this.ROIShowBinaryButtonToolTipText);
            this.ROIShowBinaryButtonListener = addlistener(this.ROIShowBinaryButton,'ItemStateChanged',@this.listenerROIShowBinaryButton);
            
            % Create subpanel to hold foreground color and opacity controls.
            subpanel = toolpack.component.TSPanel('3dlu,r:p,40dlu,f:p,f:p','3dlu,f:p,f:p,f:p,3dlu');
            subpanel.add(this.ROIColorLabel,'xy(2,2)');
            subpanel.add(this.ROIColorButton,'xy(3,2,''l,c'')');
            subpanel.add(this.ROIOpacityLabel,'xy(2,3)');
            subpanel.add(this.ROIOpacitySlider,'xywh(3,3,2,1)');
            subpanel.add(this.ROIThicknessLabel,'xy(2,4)');
            subpanel.add(this.ROIThicknessSlider,'xywh(3,4,2,1)');

            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,3dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(subpanel,'xy(1,1)');
            panel.add(this.ROIShowBinaryButton,'xy(3,1)');
            
            % Add panel to section
            this.ROISettingsSection.add(panel);
            
            % Save objects to handles structure
            this.SectionHandles.ROISettings = {...
                this.ROIColorLabel,...
                this.ROIColorButton,...
                this.ROIOpacityLabel,...
                this.ROIOpacitySlider,...
                this.ROIThicknessLabel,...
                this.ROIThicknessSlider,...
                this.ROIShowBinaryButton};
        end
        function layoutROIDrawSection(this)
            % Create buttons for drawing tools
            this.DrawRectangleButton = toolpack.component.TSButton(this.DrawRectangleButtonStr,this.DrawRectangleButtonIcon);
            this.DrawRectangleButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.DrawRectangleButton,this.DrawRectangleButtonToolTipText);
            addlistener(this.DrawRectangleButton,'ActionPerformed',@this.listenerDrawRectangleButton);
            
            this.DrawPolygonButton = toolpack.component.TSButton(this.DrawPolygonButtonStr,this.DrawPolygonButtonIcon);
            this.DrawPolygonButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.DrawPolygonButton,this.DrawPolygonButtonToolTipText);
            addlistener(this.DrawPolygonButton,'ActionPerformed',@this.listenerDrawPolygonButton);
            
            this.DrawFreehandButton = toolpack.component.TSButton(this.DrawFreehandButtonStr,this.DrawFreehandButtonIcon);
            this.DrawFreehandButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            iptui.internal.utilities.setToolTipText(this.DrawFreehandButton,this.DrawFreehandButtonToolTipText);
            addlistener(this.DrawFreehandButton,'ActionPerformed',@this.listenerDrawFreehandButton);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g,f:p:g,f:p:g'); %(columns,rows)
            panel.add(this.DrawRectangleButton,	'xy(1,1)');
            panel.add(this.DrawPolygonButton,   'xy(1,2)');
            panel.add(this.DrawFreehandButton,	'xy(1,3)');
            
            % Add panel to section
            this.ROIDrawSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.ROIDraw = {...
                this.DrawRectangleButton,...
                this.DrawPolygonButton,...
                this.DrawFreehandButton};
        end
        function layoutROIResponseSection(this)
            % Create OK and Cancel buttons
            this.OKButton = toolpack.component.TSButton(this.OKButtonStr,this.OKButtonIcon);
            this.OKButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.OKButton,this.OKButtonToolTipText);
            addlistener(this.OKButton,'ActionPerformed',@this.listenerOKButton);
            
            this.CancelButton = toolpack.component.TSButton(this.CancelButtonStr,this.CancelButtonIcon);
            this.CancelButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            iptui.internal.utilities.setToolTipText(this.CancelButton,this.CancelButtonToolTipText);
            addlistener(this.CancelButton,'ActionPerformed',@this.listenerCancelButton);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,f:p','f:p:g'); %(columns,rows)
            panel.add(this.OKButton,	 'xy(1,1)');
            panel.add(this.CancelButton, 'xy(2,1)');
            
            % Add panel to section
            this.ROIResponseSection.add(panel);
            
            % Update toolstrip handles structure
            this.SectionHandles.ROIResponse = {...
                this.OKButton,...
                this.CancelButton};
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
            this.setTSButtonIconFromImage(this.OpticalFlowColorButton,btui.utils.makeicon(16,16,this.OpticalFlowColorDefault));
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
        function listenerBackendROI(this,~,~)
            % Show ROI whenever it is modified.
            if ~isvalid(this); return; end %return if app is closed
            if ~this.ROICheckBox.Selected
                this.ROICheckBox.Selected = true;
            else
                this.showROI();
            end
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
        % Home\Video controls
        %******************************************************************
        function listenerCurrentFrameText(this,obj,~)
            % Update the current frame.
            ind = str2double(obj.Text); %index of current frame
            if isscalar(ind) && isfinite(ind) && ind==floor(ind) && ind>=this.FrameSlider.Minimum && ind<=this.FrameSlider.Maximum
                this.FrameSlider.Value = ind;
            else %reset to previous value
                obj.Text = num2str(this.FrameSlider.Value);
            end
        end
        function listenerEndFrameText(this,obj,~)
            % Update the ending frame.
            ind = str2double(obj.Text); %index of starting frame
            if isscalar(ind) && isfinite(ind) && ind==floor(ind) && ind<=this.Backend.NumFrames && ind>=this.FrameSlider.Minimum
                this.FrameSlider.Maximum = ind;
                this.Backend.EndFrame = ind;
            else %reset to previous value
                obj.Text = num2str(this.FrameSlider.Maximum);
            end
        end
        function listenerFrameRateText(this,obj,~)
            % Update the frame rate.
            fps = str2double(obj.Text); %new fps
            if isscalar(fps) && isfinite(fps) && fps>0 && fps==floor(fps)
                this.Backend.FPS = fps;
            else %reset to previous value
                obj.Text = num2str(this.Backend.FPS);
            end
        end
        function listenerFrameSlider(this,~,~)
            % Update the current frame in the backend.
            this.Backend.CurrentFrame = this.FrameSlider.Value;
        end
        function listenerNextFrameButton(this,~,~)
            % Go to the next frame.
            this.FrameSlider.Value = min(this.FrameSlider.Value+1,this.FrameSlider.Maximum);
        end
        function listenerPlayButton(this,~,~)
            % Play or pause the video

            % Set flag to notify play state
            this.ContinuePlayingFlag = true;

            % Change PlayButton icon and tooltiptext to pause
            this.PlayButton.Icon = this.PauseButtonIcon;
            iptui.internal.utilities.setToolTipText(this.PlayButton,this.PauseButtonToolTipText);

            try
                playvideo(this.Backend);

                this.PlayButton.Icon = this.PlayButtonIcon;
                iptui.internal.utilities.setToolTipText(this.PlayButton,this.PlayButtonToolTipText);
            catch ME
                if strcmp(ME.identifier,'images:SegmentationBackend:emptyMask')

                    % Change PlayButton icon and tooltiptext to play
                    this.PlayButton.Icon = this.PlayButtonIcon;
                    iptui.internal.utilities.setToolTipText(this.PlayButton,this.PlayButtonToolTipText);

%                     iptui.internal.invalidSegmentationDialog();
%                     setControlsToEmptyMask(this);
                elseif strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
                    % Deleting the app while it is running will cause this
                    % to become an invalid handle. Do nothing, the app is
                    % already being destroyed.
                else
                    rethrow(ME)
                end
            end
        end
        function listenerPlayButtonState(this,~,~)
            % Update state of play button.
            this.ContinuePlayingFlag = ~this.ContinuePlayingFlag;
            if ~this.ContinuePlayingFlag
                pausevideo(this.Backend);
            end
        end
        function listenerPrevFrameButton(this,~,~)
            % Go to the previous frame.
            this.FrameSlider.Value = max(this.FrameSlider.Value-1,this.FrameSlider.Minimum);
        end
        function listenerStartFrameText(this,obj,~)
            % Update the starting frame.
            ind = str2double(obj.Text); %index of starting frame
            if isscalar(ind) && isfinite(ind) && ind==floor(ind) && ind>0  && ind<=this.FrameSlider.Maximum
                this.FrameSlider.Minimum = ind;
                this.Backend.StartFrame = ind;
            else %reset to previous value
                obj.Text = num2str(this.FrameSlider.Minimum);
            end
        end
    
        %******************************************************************
        % Home\View
        %******************************************************************
        function listenerZoomInButton(this,obj,~)
            % Callback for ZoomInButton.
            himage = this.ImageHandle;
            if obj.Selected
                this.ZoomOutButton.Selected = false;
                this.PanButton.Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                himage.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomin');
                warning(warnstate);
                glassplus = setptr('glassplus');
                iptSetPointerBehavior(himage,@(hfig,~) set(hfig,glassplus{:}));
            else
                if ~(this.ZoomOutButton.Selected || this.PanButton.Selected)
                    himage.ButtonDownFcn = '';
                    iptSetPointerBehavior(himage,[]);
                end
            end
        end
        function listenerZoomOutButton(this,obj,~)
            % Callback for ZoomOutButton.
            himage = this.ImageHandle;
            if obj.Selected
                this.ZoomInButton.Selected = false;
                this.PanButton.Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                himage.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomout');
                warning(warnstate);
                glassminus = setptr('glassminus');
                iptSetPointerBehavior(himage,@(hfig,~) set(hfig,glassminus{:}));
            else
                if ~(this.ZoomInButton.Selected || this.PanButton.Selected)
                    himage.ButtonDownFcn = '';
                    iptSetPointerBehavior(himage,[]);
                end
            end
        end
        function listenerPanButton(this,obj,~)
            % Callback for PanButton.
            himage = this.ImageHandle;
            if obj.Selected
                this.ZoomOutButton.Selected = false;
                this.ZoomInButton.Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                himage.ButtonDownFcn = imuitoolsgate('FunctionHandle','impan');
                warning(warnstate);
                handcursor = setptr('hand');
                iptSetPointerBehavior(himage,@(hfig,~) set(hfig,handcursor{:}));
            else
                if ~(this.ZoomInButton.Selected || this.ZoomOutButton.Selected)
                    himage.ButtonDownFcn = '';
                    iptSetPointerBehavior(himage,[]);
                end
            end
        end
        
        %******************************************************************
        % Home\Options
        %******************************************************************
        function listenerROICheckBox(this,obj,~)
            % Toggle overlay of selected region of interest on image.
            if ~isvalid(this); return; end %return if app is closed
            
            if obj.Selected
                this.showROI();
            else
                this.hideROI();
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
        % ROI\File
        %******************************************************************
        function listenerROILoadButton(this,~,~)
            % Load ROI mask from file.
            this.status(this.ROILoadButtonStatusBarText);
            
            this.state('disable all controls'); %disable all controls until loading is complete
            bwload(this,'from file');
            
            this.status('');
        end
        function listenerROILoadButtonPopup(this,obj,~)
            % Load ROI mask based on popup menu selection.
            this.status(this.ROILoadButtonStatusBarText);
            this.state('disable all controls'); %disable all controls until loading is complete
            
            if obj.SelectedIndex==1
                bwload(this,'from file');
            elseif obj.SelectedIndex==2
                bwload(this,'from workspace');
            end
            
            this.status('');
        end
        function listenerResetButton(this,~,~)
            % Revert to default ROI mask.
            this.status(this.ResetButtonStatusBarText);
            
            this.Backend.ROI = this.Backend.DefaultROI;
            
            this.status('');
        end
        
        %******************************************************************
        % ROI\Settings
        %******************************************************************
        function listenerROIColorButton(this,obj,~)
            % Change ROI color by changing axes color.

            % Retrieve current (or default) color
            if isempty(this.Backend.ROIColor)
                clr = this.ROIColorDefault;
            else
                clr = this.Backend.ROIColor;
            end

            % Query user to select new color
            clr = uisetcolor(clr,'Select ROI Color');
            this.Backend.ROIColor = clr;

            % Update icon (unless user canceled color dialog box)
            if ~isequal(clr,0)
                this.setTSButtonIconFromImage(obj,btui.utils.makeicon(16,16,clr));

                % Set imscrollpanel axes color to apply chosen ROI color.
                this.AxesHandle.Color = clr;
            end
        end
        function listenerROIOpacitySlider(this,~,~)
            % Change ROI opacity.
            this.Backend.ROIOpacity = this.ROIOpacitySlider.Value;
            this.ROICheckBox.Selected = true;
            this.showROI();
        end
        function listenerROIThicknessSlider(this,~,~)
            % Change ROI thickness.
            this.Backend.ROIThickness = this.ROIThicknessSlider.Value;
            this.ROICheckBox.Selected = true;
            this.showROI();
        end
        function listenerROIShowBinaryButton(this,obj,~)
            % Show ROI mask as binary image.

            himage = this.ImageHandle;
            if obj.Selected
                % Set colormap of figure to gray(2).
                this.Backend.hfigure.Colormap = gray(2);

                himage.AlphaData = 1;
                this.ROICheckBox.Selected = true;
                this.showROI();
                this.ROIColorLabel.Enabled = false;
                this.ROIColorButton.Enabled = false;
                this.ROIOpacityLabel.Enabled = false;
                this.ROIOpacitySlider.Enabled = false;
                this.ROIThicknessLabel.Enabled = false;
                this.ROIThicknessSlider.Enabled = false;
            else
                % Set colormap back to original map.
                this.Backend.hfigure.Colormap = this.Colormap;

                ind = this.Backend.CurrentFrame;
                himage.CData = this.Backend.ImageSequence(:,:,:,ind);
                this.ROICheckBox.Selected = true;
                this.showROI();
                this.ROIColorLabel.Enabled = true;
                this.ROIColorButton.Enabled = true;
                this.ROIOpacityLabel.Enabled = true;
                this.ROIOpacitySlider.Enabled = true;
                this.ROIThicknessLabel.Enabled = true;
                this.ROIThicknessSlider.Enabled = true;
            end
        end
    
        %******************************************************************
        % ROI\Draw
        %******************************************************************
        function listenerDrawRectangleButton(this,~,~)
            % Draw one or more polygons on the image.

            % Reset ROI and drawing tools
%             this.Backend.ROI = true(this.Backend.ImageSize);
            this.deleteROIDrawTools();

            % Instantiate the impoly container
            if ~(isa(this.RectangleContainer,'btui.internal.ImrectModeContainer') && isvalid(this.RectangleContainer))
                haxes = findobj(this.Backend.hScrollPanel,'type','axes');
                this.RectangleContainer = btui.internal.ImrectModeContainer(haxes);
                addlistener(this.RectangleContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end

            % Update toolstrip controls
            this.state('wait for response');

            % Start letting user draw freehand contours
            this.RectangleContainer.enableInteractivePlacement();

            % Update status bar text
            this.status(this.DrawRectangleButtonStatusBarText);
        end
        function listenerDrawPolygonButton(this,~,~)
            % Draw one or more polygons on the image.

            % Reset ROI and drawing tools
%             this.Backend.ROI = true(this.Backend.ImageSize);
            this.deleteROIDrawTools();

            % Instantiate the impoly container
            if ~(isa(this.PolygonContainer,'iptui.internal.ImpolyModeContainer') && isvalid(this.PolygonContainer))
                haxes = findobj(this.Backend.hScrollPanel,'type','axes');
                this.PolygonContainer = iptui.internal.ImpolyModeContainer(haxes);
                addlistener(this.PolygonContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end

            % Update toolstrip controls
            this.state('wait for response');

            % Start letting user draw freehand contours
            this.PolygonContainer.enableInteractivePlacement();

            % Update status bar text
            this.status(this.DrawPolygonButtonStatusBarText);
        end
        function listenerDrawFreehandButton(this,~,~)
            % Draw one or more contours on the image.

            % Reset ROI and drawing tools
%             this.Backend.ROI = true(this.Backend.ImageSize);
            this.deleteROIDrawTools();

            % Instantiate the imfreehand container
            if ~(isa(this.FreehandContainer,'iptui.internal.ImfreehandModeContainer') && isvalid(this.FreehandContainer))
                haxes = findobj(this.Backend.hScrollPanel,'type','axes');
                this.FreehandContainer = iptui.internal.ImfreehandModeContainer(haxes);
                addlistener(this.FreehandContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end

            % Update toolstrip controls
            this.state('wait for response');

            % Start letting user draw freehand contours
            this.FreehandContainer.enableInteractivePlacement();

            % Update status bar text
            this.status(this.DrawFreehandButtonStatusBarText);
        end
        function listenerDrawObjectContainer(this,~,evt)
        % Set color and opacity of ROI when an impoly object is added.
            src = evt.AffectedObject;
            if ~isempty(src.hROI) && isvalid(src.hROI(end))
                roi = src.hROI(end);
                hpatch = findobj(roi,'type','patch');
                if ~isempty(hpatch)
                    hpatch.FaceColor = this.Backend.ROIColor;
                    hpatch.FaceAlpha = this.Backend.ROIOpacity/100;
                end
            end
        end
        
        %******************************************************************
        % ROI\Response
        %******************************************************************
        function listenerOKButton(this,~,~)
            % Accept the current ROI.
            roi = false(size(this.Backend.ROI));
            
            % Check if rectangles were used
            if isa(this.RectangleContainer,'btui.internal.ImrectModeContainer') && isvalid(this.RectangleContainer)
                rectangles = this.RectangleContainer.hROI;
                rectangles = rectangles(isvalid(rectangles));
                for ii=1:numel(rectangles)
                    roi = roi|createMask(rectangles(ii));
                end
            end
            
            % Check if polygons were used
            if isa(this.PolygonContainer,'iptui.internal.ImpolyModeContainer') && isvalid(this.PolygonContainer)
                polygons = this.PolygonContainer.hROI;
                polygons = polygons(isvalid(polygons));
                for ii=1:numel(polygons)
                    roi = roi|createMask(polygons(ii));
                end
            end
            
            % Check if freehand contours were used
            if isa(this.FreehandContainer,'iptui.internal.ImfreehandModeContainer') && isvalid(this.FreehandContainer)
                freehands = this.FreehandContainer.hROI;
                freehands = freehands(isvalid(freehands));
                for ii=1:numel(freehands)
                    roi = roi | createMask(freehands(ii));
                end
            end
            
            % Delete existing drawing tools
            this.deleteROIDrawTools();
            
            this.Backend.ROI = roi;
            this.status('');
            this.state('idle');
        end
        function listenerCancelButton(this,~,~)
            % Reject the current ROI.
            this.status('');
            this.deleteROIDrawTools();
            this.state('idle');
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
                    btui.utils.disable(this.SectionHandles.Settings);
                case 2
                    this.Backend.OpticalFlowAlg = 'horn-schunck';
                    this.MethodButton.Text = this.MethodButtonPopupOption2Title;
                    this.OpticalFlowCheckBox.Selected = true;
                    this.showOpticalFlow();
                    btui.utils.enable(this.SectionHandles.Settings);
                case 3
                    this.Backend.OpticalFlowAlg = 'lucas-kanade';
                    this.MethodButton.Text = this.MethodButtonPopupOption3Title;
                    this.OpticalFlowCheckBox.Selected = true;
                    this.showOpticalFlow();
                    btui.utils.enable(this.SectionHandles.Settings);
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
                this.setTSButtonIconFromImage(obj,btui.utils.makeicon(16,16,clr));
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
                set(haxes,'Color',this.ROIColorDefault); %initialize overlay color by setting axes color
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
                            im = btui.utils.imframe(fullfile(pathname,filename),'all','class','uint8');
                        else
                            im = [];
                        end
                    case 'from workspace'
                        % Query user to select image sequence from workspace
                        im = btui.utils.importdlg();
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
        % ROI - loading, drawing, etc.
        %******************************************************************
        function bwload(this,location)
            % Load an ROI mask.
            switch location
                case 'from file'
                    % Query user to select ROI mask from file
                    [filename,pathname] = uigetfile(...
                        {'*.jpg;*.tif;*.png;*.gif','All Image Files'; '*.*','All Files'},...
                        'Load ROI Mask From File');
%                     filename = imgetfile();
                    if ~isempty(filename) && ~isequal(filename,0)
                        roi = imread(fullfile(pathname,filename));
                    else
                        roi = [];
                    end
                case 'from workspace'
                    % Query user to select image sequence from workspace
                    roi = btui.utils.importdlg();
            end
            
            if ~isempty(roi)
                [m,n,~,~] = size(this.Backend.ImageSequence);
                isvalidtype = islogical(roi) && ismatrix(roi) && isequal(size(roi,1),m) && isequal(size(roi,2),n);
                if ~isvalidtype
                    errdlg = errordlg(this.InvalidMaskDlgMessage,this.InvalidMaskDlgTitle,'modal');
                    % We need the error dialog to be blocking, otherwise
                    % listenerROILoadButton() is invoked before the dialog finishes
                    % setting itself up and becomes modal.
                    uiwait(errdlg);
                    % Drawnow is necessary so that imgetfile dialog will
                    % enforce modality in next call to imgetfile that
                    % arises from recursion.
                    drawnow;
                    bwload(this,location);
                    return;
                else                        
                    this.Backend.ROI = roi;
                    this.state('roi loaded');
                end
            else
                this.state('idle');
            end
        end
        function deleteROIDrawTools(this)
            % Delete existing imrect/impoly/imfreehand tools.
            if isa(this.RectangleContainer,'btui.internal.ImrectModeContainer') && isvalid(this.RectangleContainer);
                % Diasble ability to place new imrect objects
                disableInteractivePlacement(this.RectangleContainer);
                
                % Look for and delete current imrect objects
                rectangles = this.RectangleContainer.hROI;
                rectangles = rectangles(isvalid(rectangles));
                for ii=1:numel(rectangles)
                    delete(rectangles(ii));
                end
                
                % Delete imrect container
                delete(this.RectangleContainer);
            end
            
            if isa(this.PolygonContainer,'iptui.internal.ImpolyModeContainer') && isvalid(this.PolygonContainer);
                % Diasble ability to place new impoly objects
                disableInteractivePlacement(this.PolygonContainer);
                
                % Look for and delete current impoly objects
                polygons = this.PolygonContainer.hROI;
                polygons = polygons(isvalid(polygons));
                for ii=1:numel(polygons)
                    delete(polygons(ii));
                end
                
                % Delete impoly container
                delete(this.PolygonContainer);
            end
            
            if isa(this.FreehandContainer,'iptui.internal.ImfreehandModeContainer') && isvalid(this.FreehandContainer)
                % Diasble ability to place new imfreehand objects
                disableInteractivePlacement(this.FreehandContainer);
                
                % Look for and delete current imfreehand objects
                freehands = this.FreehandContainer.hROI;
                freehands = freehands(isvalid(freehands));
                for ii=1:numel(freehands)
                    delete(freehands(ii));
                end
                
                % Delete imfreehand container
                delete(this.FreehandContainer);
            end
        end
        function showROI(this)
            % Show current region of interest.
            this.ImageHandle.CDataMapping = 'scaled';
            this.ImageHandle.AlphaData = this.Backend.AlphaData;
        end
        function hideROI(this)
            % Hide current region of interest.
            this.ImageHandle.CDataMapping = 'scaled';
            this.ImageHandle.AlphaData = ones(this.Backend.ImageSize);
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
                    btui.utils.disable(this.AllHandles);
                    btui.utils.enable(this.SectionHandles.VideoControls); %allow video controls
                    btui.utils.enable(this.SectionHandles.ROIResponse); %wait for user response
                    
                case 'idle'
                    % This is the state in which an image is in view, so
                    % enable all image editing controls, but do not reset
                    % default values.
                    btui.utils.enable(this.TabHandles.Home);
                    btui.utils.enable(this.TabHandles.ROI);
                    btui.utils.enable(this.TabHandles.OpticalFlow);
                    btui.utils.disable(this.SectionHandles.ROIResponse);
                    
                case 'image loaded'
                    % Reset the ShowBinaryButton
                    if this.ROIShowBinaryButton.Selected
                        this.ROIShowBinaryButton.Selected = false;
                        % This drawnow ensures that the callback triggered when
                        % show binary is unselected fires immediately.
                        drawnow;
                    end
                    
                    % Enable relevant controls
                    btui.utils.enable(this.TabHandles.Home);
                    btui.utils.enable(this.TabHandles.ROI);
                    btui.utils.enable(this.TabHandles.OpticalFlow);
                    btui.utils.disable(this.SectionHandles.ROIResponse);
                    
                    % Return to default parameter values
                    this.StartFrameText.Text = this.StartFrameTextDefault;
                    this.EndFrameText.Text = num2str(this.Backend.NumFrames);
                    this.FrameSlider.Minimum = this.FrameSliderMinimumDefault;
                    this.FrameSlider.Maximum = this.Backend.NumFrames;
                    this.FrameSlider.Value = this.FrameSliderDefault;
                    this.CurrentFrameText.Text = this.CurrentFrameTextDefault;
                    this.CurrentFrameUnits.Text = sprintf('/ %d',this.Backend.NumFrames);
                    this.FrameRateText.Text = this.FrameRateTextDefault;
                    
                    btui.utils.deselect(this.SectionHandles.View); %deselect all zooming and panning buttons
                    
                    % Update PreviousState
                    this.PreviousState = str;
                    
                case 'initial'
                    btui.utils.disable(this.AllHandles);
                    btui.utils.enable(this.SectionHandles.File); %allow user to load an image sequence
                    
                    % Default video controls
                    this.CurrentFrameText.Text = this.CurrentFrameTextDefault;
                    this.CurrentFrameUnits.Text = this.CurrentFrameUnitsDefault;
                    this.FrameRateText.Text = this.FrameRateTextDefault;
                    this.StartFrameText.Text = this.StartFrameTextDefault;
                    this.EndFrameText.Text = this.EndFrameTextDefault;
                    this.FrameSlider.Value = this.FrameSliderDefault;
                    this.FrameSlider.Maximum = 100;
                    
                    % Default view settings
                    btui.utils.deselect(this.SectionHandles.View);
                    
                    % Default ROI settings
                    this.setTSButtonIconFromImage(this.ROIColorButton,btui.utils.makeicon(16,16,this.ROIColorDefault));
                    this.ROIOpacitySlider.Value = this.ROIOpacitySliderDefault;
                    this.ROIThicknessSlider.Value = this.ROIThicknessSliderDefault;
                    
                case 'roi loaded'
                    btui.utils.enable(this.TabHandles.Home);
                    btui.utils.enable(this.TabHandles.ROI);
                    btui.utils.enable(this.TabHandles.OpticalFlow);
                    btui.utils.disable(this.SectionHandles.ROIResponse);
                    
                case 'disable all controls'
                    btui.utils.disable(this.AllHandles);
                    
                case 'enable all usable controls'
                    btui.utils.enable(this.AllHandles);
                    btui.utils.disable(this.SectionHandles.ROIResponse);
                    
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

