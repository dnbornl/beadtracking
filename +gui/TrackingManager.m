classdef TrackingManager < handle
%GUI.TRACKINGMANAGER Add tracking tools to a GUI.
%   GUI.TRACKINGMANAGER(APP) manages detection and tracking controls in a 
%   specified APP.
%
%   THIS = GUI.TRACKINGMANAGER(APP) returns the object itself, which can be
%   stored, for example, as a property of the APP.
%
%   Requirements:
%   1) The input APP must have a dependent property called AxesHandle that
%   returns an axes handle on which to apply draw regions of interest.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        DataPath
        
        Tab
        FileSection
        SettingsSection
        TrackingSection
        
        % File
        LoadButton

        % Settings
        ColorLabel
        ColorButton
        LinewidthLabel
        LinewidthSlider
        OpacityLabel
        OpacitySlider
        ThresholdLabel
        ThresholdSlider

        % Tracking
        TrackingButton
    end
    properties (SetObservable=true)
        Color
        Opacity
        Linewidth
        Flag = true;
        TrackingFlag = false;
        Detections
    end
    properties (Dependent)
        Handles
    end
    properties (Dependent,SetObservable=true)
        Threshold
    end
    properties (Access=private,Constant)
        % File
        LoadIcon          = gui.Icon.IMPORT_24;
        LoadPopupIcon     = gui.Icon.IMPORT_16;
        
        % Settings
        
        % Tracking
        TrackingIcon    = gui.Icon.RUN_24;
        
    end %icons
    properties (Access=private,Constant)
        % File
        LoadStr               	= sprintf('Load\nDetections');
        LoadTooltip             = 'Load detections from workspace or file';
        LoadStatus              = 'Loading precomputed detections...';
        LoadPopupOption1      	= 'Load Detections From File';
        LoadPopupOption2      	= 'Load Detections From Workspace';
        InvalidDetectionsDlgMessage  	= 'Precomputed detections must be a cell array, with one cell for every image frame. Please choose a valid file.';
        InvalidDetectionsDlgTitle   	= 'Invalid Detections';
        
        % Settings
        ColorLabelStr          	= 'Color';
        ColorTooltip         	= 'Change detection color';
        LinewidthLabelStr   	= 'Linewidth';
        LinewidthTooltip        = 'Adjust detection line width';
        OpacityLabelStr         = 'Opacity';
        OpacityTooltip          = 'Adjust detection opacity';
        ThresholdLabelStr         = 'Threshold';
        ThresholdTooltip          = 'Adjust detection threshold';
    
        % Tracking
        TrackingStr             = 'Start Tracking';
        TrackingTooltip         = 'Track detections across all frames';
        TrackingStatus          = 'Tracking detections...please be patient.';
    end %strings
    properties (Constant)
        DefaultColor        = [0.9294    0.6941    0.1255];
        DefaultLinewidth	= 1;
        DefaultOpacity      = 40;
        DefaultThreshold    = 100;
    end %defaults
    
    methods % public
        function this = TrackingManager(app,toolgroup)
            % Set properties
            this.DataPath = app.DataPath;
            this.Color = this.DefaultColor;
            this.Linewidth = this.DefaultLinewidth;
            this.Opacity = this.DefaultOpacity/100;
            
            % Add tab to toolgroup
            this.Tab = toolgroup.addTab('TrackingTab','Tracking');
            
            % Add sections to tab
            this.FileSection        = this.Tab.addSection('FileSection','File');
            this.SettingsSection   	= this.Tab.addSection('SettingsSection','Settings');
            this.TrackingSection    = this.Tab.addSection('TrackingSection','Tracking');
            
            % Create widgets for each section and add listeners
            this.layoutFileSection();
            this.layoutSettingsSection();
            this.layoutTrackingSection();
            this.addtooltip();
            this.addlisteners(app);
        end
        function reset(this)            
            gui.setTSButtonIconFromImage(this.ColorButton,makeicon(16,16,this.DefaultColor));
            this.LinewidthSlider.Value = this.DefaultLinewidth;
            this.OpacitySlider.Value = this.DefaultOpacity;
            this.ThresholdSlider.Value = this.DefaultThreshold;
        end
    end
    
    %======================================================================
    %
    % Private methods
    % --------------------
    % These functions are only called within this class file.
    %
    %======================================================================
    methods (Access=private)
        function addlisteners(this,app)
            addlistener(this.LoadButton,'ActionPerformed',@(obj,evt) listenerLoadButton(this,obj,evt,app));
            addlistener(this.LoadButton.Popup,'ListItemSelected',@(obj,evt) listenerLoadButtonPopup(this,obj,evt,app));
            
            addlistener(this.ColorButton,'ActionPerformed',@this.listenerColorButton);
            addlistener(this.LinewidthSlider,'StateChanged',@this.listenerLinewidthSlider);
            addlistener(this.OpacitySlider,'StateChanged',@this.listenerOpacitySlider);
            addlistener(this.ThresholdSlider,'StateChanged',@this.flagApp);
            
            addlistener(this.TrackingButton,'ActionPerformed',@(obj,evt) listenerTrackingButton(this,obj,evt,app));
        end
        function addtooltip(this)
            iptui.internal.utilities.setToolTipText(this.LoadButton,this.LoadTooltip);
            
            iptui.internal.utilities.setToolTipText(this.ColorButton,this.ColorTooltip);
            iptui.internal.utilities.setToolTipText(this.LinewidthSlider,this.LinewidthTooltip);
            iptui.internal.utilities.setToolTipText(this.OpacitySlider,this.OpacityTooltip);
            
            iptui.internal.utilities.setToolTipText(this.TrackingButton,this.TrackingTooltip);
        end
        function matload(this,location,app)
            % Load precomputed detections.
            this.status(this.LoadStatus);
            app.state('disable all controls'); %disable all controls until loading is complete
            
            switch location
                case 'from file' %query user to select precomputed detections from file
                        
                    cwd = pwd; %get current working directory
                    
                    % Change to directory where data is stored. If the user
                    % did not specify DataPath or if the value of DataPath 
                    % is invalid for the current machine, then look in the 
                    % default directory for NEURO demos.
                    if ~isempty(this.DataPath) && exist(this.DataPath,'dir')
                        cd(this.DataPath);
                    else
                        cd(fullfile(beadtracking.path,'resources','demos'));
                    end
                    
                    [filename,pathname] = uigetfile(...
                        {'*.mat','MAT-files'; '*.*','All Files'},...
                        'Load Precomputed Detections From File');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    % If the user selected a file, load the precomputed
                    % detections. Otherwise, return an empty array.
                    if ~isempty(filename) && ~isequal(filename,0)
                        data = load(fullfile(pathname,filename));
                        detection = getfieldifexists(data,'detection');
                        refinement = getfieldifexists(data,'refinement');
                        if ~isempty(refinement)
                            detections = cellfun(@(x,y) [x,y],refinement.blobs,refinement.scores,'uni',0);
                        elseif ~isempty(detection)
                            detections = cellfun(@(x,y) [x,y],detection.blobs,detection.scores,'uni',0);
                        else
                            error('The selected file does not contains valid data. Try another file.');
                        end
                    else
                        detections = [];
                    end
                case 'from workspace'
                    % Query user to select image sequence from workspace
                    detections = importdlg();
            end
            
            if ~isempty(detections)
                [~,~,~,q] = size(app.Backend.ImageSequence);
                isvalidtype = iscell(detections) && isequal(length(detections),q);
                if ~isvalidtype
                    errdlg = errordlg(this.InvalidDetectionsDlgMessage,this.InvalidDetectionsDlgTitle,'modal');
                    % We need the error dialog to be blocking, otherwise
                    % listenerTrackingLoadButton() is invoked before the dialog finishes
                    % setting itself up and becomes modal.
                    uiwait(errdlg);
                    % Drawnow is necessary so that imgetfile dialog will
                    % enforce modality in next call to imgetfile that
                    % arises from recursion.
                    drawnow;
                    matload(this,location,app);
                    return;
                else        
                    this.Detections = detections;
                    app.state('detections loaded');
                end
            else
                app.state('idle');
            end
            this.status('');
        end
        function deleteDrawTools(this)
            % Delete existing imrect/impoly/imfreehand tools.
            if isa(this.RectangleContainer,'gui.ImrectModeContainer') && isvalid(this.RectangleContainer);
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
            
            if isa(this.PolygonContainer,'gui.ImpolyModeContainer') && isvalid(this.PolygonContainer);
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
            
            if isa(this.FreehandContainer,'gui.ImfreehandModeContainer') && isvalid(this.FreehandContainer)
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
        function status(this,str)
            % Update StatusBarText in parent app.
            iptui.internal.utilities.setStatusBarText(this.Tab.Parent.Name,str);
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
            % Create button for loading precomputed detections
            this.LoadButton = toolpack.component.TSSplitButton(this.LoadStr,this.LoadIcon);
            this.LoadButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            % Add popup menu to load button
            items(1) = struct(...
                'Title',this.LoadPopupOption1,...
                'Description','',...
                'Icon',this.LoadPopupIcon,...
                'Help',[],...
                'Header',false);
            items(2) = struct(...
                'Title',this.LoadPopupOption2,...
                'Description','',...
                'Icon',this.LoadPopupIcon,...
                'Help',[],...
                'Header',false);
            this.LoadButton.Popup = toolpack.component.TSDropDownPopup(items,'icon_text');
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,f:p','f:p:g'); %(columns,rows)
            panel.add(this.LoadButton,'xy(1,1)');
            
            % Add panel to section
            this.FileSection.add(panel);
        end
        function layoutSettingsSection(this)
            % Create button to set object color
            % Note: there is no MCOS interface to set the icon of a TSButton directly from a uint8 buffer.
            this.ColorLabel = toolpack.component.TSLabel(this.ColorLabelStr);
            this.ColorButton = toolpack.component.TSButton();
            gui.setTSButtonIconFromImage(this.ColorButton,makeicon(16,16,this.DefaultColor));
            
            % Linewidth slider
            this.LinewidthLabel = toolpack.component.TSLabel(this.LinewidthLabelStr);
            this.LinewidthSlider = toolpack.component.TSSlider(1,5,this.DefaultLinewidth);
            this.LinewidthSlider.MinorTickSpacing = 0.5;
            
            % Opacity slider
            this.OpacityLabel = toolpack.component.TSLabel(this.OpacityLabelStr);
            this.OpacitySlider = toolpack.component.TSSlider(0,100,this.DefaultOpacity);
            this.OpacitySlider.MinorTickSpacing = 0.1;
            
            % Create subpanel to hold display controls
            subpanel = toolpack.component.TSPanel('3dlu,r:p,40dlu,f:p,f:p','3dlu,f:p,f:p,f:p,3dlu');
            subpanel.add(this.ColorLabel,'xy(2,2)');
            subpanel.add(this.ColorButton,'xy(3,2,''l,c'')');
            subpanel.add(this.OpacityLabel,'xy(2,3)');
            subpanel.add(this.OpacitySlider,'xywh(3,3,2,1)');
            subpanel.add(this.LinewidthLabel,'xy(2,4)');
            subpanel.add(this.LinewidthSlider,'xywh(3,4,2,1)');

            % Threshold slider
            this.ThresholdLabel = toolpack.component.TSLabel(this.ThresholdLabelStr);
            this.ThresholdSlider = toolpack.component.TSSlider(80,100,this.DefaultThreshold);
            this.ThresholdSlider.MinorTickSpacing = 0.1;
            
            % Create subpanel to hold display controls
            subpanel2 = toolpack.component.TSPanel('3dlu,r:p,40dlu,f:p,f:p','3dlu,f:p,f:p,f:p,3dlu');
            subpanel2.add(this.ThresholdLabel,'xy(2,3)');
            subpanel2.add(this.ThresholdSlider,'xywh(3,3,2,1)');
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,3dlu,f:p,1dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(subpanel,'xy(1,1)');
            panel.add(subpanel2,'xy(3,1)');
            
            % Add panel to section
            this.SettingsSection.add(panel);
        end
        function layoutTrackingSection(this)
            % Create buttons for tracking
            this.TrackingButton = toolpack.component.TSButton(this.TrackingStr,this.TrackingIcon);
            this.TrackingButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g'); %(columns,rows)
            panel.add(this.TrackingButton,'xy(1,1)');
            
            % Add panel to section
            this.TrackingSection.add(panel);
        end
    end
    
    %======================================================================
    %
    % Listener methods
    % --------------------
    % These functions are called when specific actions are executed on the
    % manager, such as clicking on a button or repositioning a slider.
    %
    %======================================================================
    methods (Access=private)
        %******************************************************************
        % File
        %******************************************************************
        function listenerLoadButton(this,~,~,app)
            % Load precomputed detections from file.
            matload(this,'from file',app);
        end
        function listenerLoadButtonPopup(this,obj,~,app)
            % Load precomputed detections based on popup menu selection.
            if obj.SelectedIndex==1
                matload(this,'from file',app);
            elseif obj.SelectedIndex==2
                matload(this,'from workspace',app);
            end
        end
        
        %******************************************************************
        % Settings
        %******************************************************************
        function flagApp(this,~,~)
            % Notify app that ROI properties have been modified.
            this.Flag = ~this.Flag;
        end
        function listenerColorButton(this,obj,~)
            % Change detection color by changing axes color.
            % ----------------------------------------
            % Retrieve current (or default) color
            if isempty(this.Color)
                clr = str2rgb(this.DefaultColor);
            else
                clr = this.Color;
            end

            % Query user to select new color
            clr = uisetcolor(clr,'Select ROI Color');

            % Update icon (unless user canceled color dialog box)
            if ~isequal(clr,0)
                gui.setTSButtonIconFromImage(obj,makeicon(16,16,clr));
                this.Color = clr;
            end
        end
        function listenerLinewidthSlider(this,~,~)
            % Change detection linewidth.
            % ----------------------------------------
            % Retrieve current (or default) linewidth
            if isempty(this.Linewidth)
                x = this.DefaultLinewidth;
            else
                x = this.Linewidth;
            end
            
            if ~isequal(x,this.LinewidthSlider.Value)
                this.Linewidth = this.LinewidthSlider.Value;
            end
        end
        function listenerOpacitySlider(this,~,~)
            % Change detection opactiy.
            % ----------------------------------------
            % Retrieve current (or default) opacity
            if isempty(this.Opacity)
                x = this.DefaultOpacity;
            else
                x = this.Opacity;
            end
            
            if ~isequal(x,this.OpacitySlider.Value)
                this.Opacity = this.OpacitySlider.Value/100;
            end
        end
    
        %******************************************************************
        % Tracking
        %******************************************************************
        function listenerTrackingButton(this,~,~,app)
            % Track detections across all frames.
            this.status(this.TrackingStatus);
            this.TrackingFlag = ~this.TrackingFlag;
        end
    end
    
    % Set/Get property methods.
    methods
        %******************************************************************
        % Set
        %******************************************************************
        function set.Detections(this,value)
            validateattributes(value,{'cell'},{'vector'});
            this.Detections = value;
        end
        
        %******************************************************************
        % Get
        %******************************************************************
        function h = get.Handles(this)
            h.File = {...
                this.LoadButton};
            h.Settings = {...
                this.ColorLabel,...
                this.ColorButton,...
                this.LinewidthLabel,...
                this.LinewidthSlider,...
                this.OpacityLabel,...
                this.OpacitySlider,...
                this.ThresholdLabel,...
                this.ThresholdSlider};
            h.Tracking = {...
                this.TrackingButton};
            h.All = [...
                h.File,...
                h.Settings,...
                h.Tracking];
        end
        function thold = get.Threshold(this)
            thold = this.ThresholdSlider.Value/100;
        end
    end
    
end

