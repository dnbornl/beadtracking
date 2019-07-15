classdef DetectionManager < handle
%GUI.DETECTIONMANAGER Add tracking tools to a GUI.
%   GUI.DETECTIONMANAGER(APP) manages detection controls in a specified
%   APP.
%
%   THIS = GUI.DETECTIONMANAGER(APP) returns the object itself, which can
%   be stored, for example, as a property of the APP.
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
        ExportButton
        
        % Settings
        ColorLabel
        ColorButton
        LinewidthLabel
        LinewidthSlider
        OpacityLabel
        OpacitySlider
        RadiiLabel
        RadiiTextField
        SensitivityLabel
        SensitivitySlider
        UpdateButton
    end
    properties (SetObservable=true)
        Color
        Flag = true;
        Detections
    end
    properties (Dependent)
        Opacity
        Linewidth
        Radii
        Sensitivity
        Handles
    end
    properties (Access=private,Constant) %icons
        LoadIcon          = gui.Icon.IMPORT_24;
        LoadPopupIcon     = gui.Icon.IMPORT_16;
        ExportIcon        = gui.Icon.EXPORT_24;
        ExportPopupIcon   = gui.Icon.EXPORT_16;
    end
    properties (Access=private,Constant) %strings
        % File
        LoadStr                     = 'Load';
        LoadTooltip                 = 'Load detections from workspace or file';
        LoadStatus                  = 'Loading precomputed detections...';
        LoadPopupOption1            = 'Load Detections From File';
        LoadPopupOption2            = 'Load Detections From Workspace';
        InvalidDetectionsDlgMessage	= 'Precomputed detections must be a cell array, with one cell for every image frame. Please choose a valid file.';
        InvalidDetectionsDlgTitle 	= 'Invalid Detections';
        
        ExportStr                   = 'Export';
        ExportTooltip               = 'Export results to file';
        ExportStatus                = 'Exporting detections...';
        ExportPopupOption1          = 'Export Detections To File';
        ExportPopupOption2          = 'Export Detections To Workspace';
        
        % Settings
        ColorLabelStr          	= 'Color';
        ColorTooltip         	= 'Change detection color';
        LinewidthLabelStr   	= 'Linewidth';
        LinewidthTooltip        = 'Adjust detection line width';
        OpacityLabelStr         = 'Opacity';
        OpacityTooltip          = 'Adjust detection opacity';
        RadiiLabelStr           = 'Radii';
        RadiiTooltip            = 'Set vector of desired radii to detect';
        SensitivityLabelStr 	= 'Sensitivity';
        SensitivityTooltip      = 'Adjust detection sensitivity';
        UpdateButtonStr         = 'Update this frame only';
        UpdatePopupOption1      = 'Update this frame only';
        UpdatePopupOption2      = 'Update all frames';
        UpdateButtonTooltip     = 'Compute detections (may take some time)';
    end
    properties (Constant) %defaults
        DefaultColor        = [0.9294    0.6941    0.1255];
        DefaultLinewidth	= 1;
        DefaultOpacity      = 20;
        DefaultRadii        = '[1 2 3 4]';
        DefaultSensitivity  = 500;
    end
    
    methods
        function this = DetectionManager(app,toolgroup)
            % Set properties
            this.DataPath = app.DataPath;
            this.Color = this.DefaultColor;
            
            % Add tab to toolgroup
            this.Tab = toolgroup.addTab('DetectionTab','Detection');
            
            % Add sections to tab
            this.FileSection        = this.Tab.addSection('FileSection','File');
            this.SettingsSection   	= this.Tab.addSection('SettingsSection','Settings');
            
            % Create widgets for each section
            this.layoutFileSection();
            this.layoutSettingsSection();
            
            % Add tooltip and listeners
            this.addtooltip();
            this.addlisteners(app);
        end
        function reset(this)
            gui.setTSButtonIconFromImage(this.ColorButton,makeicon(16,16,this.DefaultColor));
            this.Color = this.DefaultColor;
            this.OpacitySlider.Value = this.DefaultOpacity;
            this.LinewidthSlider.Value = this.DefaultLinewidth;
            this.RadiiTextField.Vlaue = this.DefaultRadii;
            this.SensitivitySlider.Value = this.DefaultSensitivity;
        end
    end
    
    methods (Access=private)
        function addtooltip(this)
            setToolTipText(this.LoadButton.Peer,        this.LoadTooltip);
            setToolTipText(this.ColorButton.Peer,       this.ColorTooltip);
            setToolTipText(this.LinewidthSlider.Peer,  	this.LinewidthTooltip);
            setToolTipText(this.OpacitySlider.Peer,     this.OpacityTooltip);
            setToolTipText(this.RadiiTextField.Peer,    this.RadiiTooltip);
            setToolTipText(this.SensitivitySlider.Peer,	this.SensitivityTooltip);
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
        function updatedetections(this,I,indices)
            blobs = cell(size(I,4),1);
            scores = cell(size(I,4),1);
            for ii=1:length(indices)
                frame = indices(ii);
                status(this,'Updating detections...(%d%%)',round((ii-1)/length(indices)*100));
                [blobs{frame},scores{frame}] = imblobs(I(:,:,:,frame),...
                    'Polarity','bright',...
                    'Radii',this.Radii,...1:0.2:3,... for example
                    'Sensitivity',this.Sensitivity,...0.5-1e-3,... for example
                    'Verbose',false);
                status(this,'Updating detections...(%d%%)',round(ii/length(indices)*100));
            end
            status(this,'');
            this.Detections = blobs;
        end
        function status(this,varargin)
            % Update StatusBarText in parent app.
            gui.setStatusBarText(this.Tab.Parent.Name,sprintf(varargin{:}));
        end
    end
    
    methods (Access=private) %layout methods
        %******************************************************************
        % These functions generate the toolstrip layout design, which 
        % includes creating widgets (panels, buttons, sliders,...), 
        % defining their properties (position, icon,...), and adding 
        % listeners for events. Each section in a toolstrip tab should have
        % its own layout method.
        %******************************************************************
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
            
            % Create button for loading precomputed detections
            this.ExportButton = toolpack.component.TSSplitButton(this.ExportStr,this.ExportIcon);
            this.ExportButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            % Add popup menu to load button
            items(1) = struct(...
                'Title',this.ExportPopupOption1,...
                'Description','',...
                'Icon',this.ExportPopupIcon,...
                'Help',[],...
                'Header',false);
            items(2) = struct(...
                'Title',this.ExportPopupOption2,...
                'Description','',...
                'Icon',this.ExportPopupIcon,...
                'Help',[],...
                'Header',false);
            this.ExportButton.Popup = toolpack.component.TSDropDownPopup(items,'icon_text');
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,f:p','f:p:g'); %(columns,rows)
            panel.add(this.LoadButton,'xy(1,1)');
            panel.add(this.ExportButton,'xy(2,1)');
            
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

            % Sensitivity slider
            this.SensitivityLabel = toolpack.component.TSLabel(this.SensitivityLabelStr);
            this.SensitivitySlider = toolpack.component.TSSlider(0,1000,this.DefaultSensitivity);
            this.SensitivitySlider.MinorTickSpacing = 1;
            
            % Radii text field
            this.RadiiLabel = toolpack.component.TSLabel(this.RadiiLabelStr);
            this.RadiiTextField = toolpack.component.TSTextField(this.DefaultRadii);
            
            % Create button for loading precomputed detections
            this.UpdateButton = toolpack.component.TSSplitButton(this.UpdateButtonStr);
            this.UpdateButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            % Add popup menu to load button
            items(1) = struct(...
                'Title',this.UpdatePopupOption1,...
                'Description','',...
                'Help',[],...
                'Header',false);
            items(2) = struct(...
                'Title',this.UpdatePopupOption2,...
                'Description','',...
                'Help',[],...
                'Header',false);
            this.UpdateButton.Popup = toolpack.component.TSDropDownPopup(items,'text_only');
            
            % Create subpanel to hold display controls
            subpanel2 = toolpack.component.TSPanel('3dlu,r:p,4dlu,50dlu,f:p,f:p,3dlu','3dlu,f:p,2dlu,f:p,1dlu,f:p,3dlu');
            subpanel2.add(this.RadiiLabel,'xy(2,2)');
            subpanel2.add(this.RadiiTextField,'xywh(4,2,2,1)');
            subpanel2.add(this.SensitivityLabel,'xy(2,4)');
            subpanel2.add(this.SensitivitySlider,'xywh(3,4,3,1)');
            subpanel2.add(this.UpdateButton,'xywh(2,6,4,1)');
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,3dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(subpanel,'xy(1,1)');
            panel.add(subpanel2,'xy(3,1)');
            
            % Add panel to section
            this.SettingsSection.add(panel);
        end
    end
    
    methods (Access=private) %listener methods
        %******************************************************************
        % These functions are called when specific actions are executed in 
        % the app, such as clicking a button or repositioning a slider.
        %******************************************************************
        function addlisteners(this,app)
            addlistener(this.LoadButton,'ActionPerformed',@(obj,evt) listenerLoadButton(this,obj,evt,app));
            addlistener(this.LoadButton.Popup,'ListItemSelected',@(obj,evt) listenerLoadButtonPopup(this,obj,evt,app));
            
            addlistener(this.ColorButton,'ActionPerformed',@this.listenerColorButton);
            addlistener(this.OpacitySlider,'StateChanged',@this.flagApp);
            addlistener(this.LinewidthSlider,'StateChanged',@this.flagApp);
%             addlistener(this.RadiiTextField,'TextEdited',@this.flagApp);
%             addlistener(this.SensitivitySlider,'StateChanged',@this.flagApp);
            
            addlistener(this.UpdateButton,'ActionPerformed',@(obj,evt) listenerUpdateButton(this,obj,evt,app));
            addlistener(this.UpdateButton.Popup,'ListItemSelected',@(obj,evt) listenerUpdateButtonPopup(this,obj,evt,app));
        end
        
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
            % Notify app that properties have been modified.
            this.Flag = ~this.Flag;
        end
        function listenerColorButton(this,obj,~)
            % Retrieve current (or default) color
            if isempty(this.Color)
                clr = str2rgb(this.DefaultColor);
            else
                clr = this.Color;
            end

            % Query user to select new color
            newclr = uisetcolor(clr,'Select ROI Color');

            % Update icon (unless user canceled color dialog box)
            if ~isequal(newclr,0) && ~isequal(newclr,clr)
                gui.setTSButtonIconFromImage(obj,makeicon(16,16,newclr));
                this.Color = clr;
                this.Flag = ~this.Flag;
            end
        end
        function listenerUpdateButton(this,~,~,app)
            % Compute detections for the current frame.
            app.state('compute detections for the current frame');
            updatedetections(this,app.Backend.ImageSequence,app.VideoControlsSection.CurrentFrame);
            app.state('idle');
        end
        function listenerUpdateButtonPopup(this,obj,~,app)
            % Compute detections based on popup menu selection.
            if obj.SelectedIndex==1
                app.state('compute detections for the current frame');
                updatedetections(this,app.Backend.ImageSequence,app.VideoControlsSection.CurrentFrame);
                app.state('idle');
            elseif obj.SelectedIndex==2
                app.state('compute detections for all frames');
                updatedetections(this,app.Backend.ImageSequence,1:app.Backend.NumFrames);
                app.state('idle');
            end
        end
    end
    
    methods %set/get dependent property methods
        function set.Detections(this,value)
            validateattributes(value,{'cell'},{'vector'});
            this.Detections = value;
        end
        function h = get.Handles(this)
            h.File = {...
                this.LoadButton,...
                this.ExportButton};
            h.Settings = {...
                this.ColorLabel,...
                this.ColorButton,...
                this.LinewidthLabel,...
                this.LinewidthSlider,...
                this.OpacityLabel,...
                this.OpacitySlider,...
                this.RadiiLabel,...
                this.RadiiTextField,...
                this.SensitivityLabel,...
                this.SensitivitySlider,...
                this.UpdateButton};
            h.All = [...
                h.File,...
                h.Settings];
        end
        function opacity = get.Opacity(this)
            opacity = this.OpacitySlider.Value/this.OpacitySlider.Maximum;
        end
        function linewidth = get.Linewidth(this)
            linewidth = this.LinewidthSlider.Value;
        end
        function sens = get.Sensitivity(this)
            sens = 0.5-0.1/(10.^(this.SensitivitySlider.Value/400));
        end
        function r = get.Radii(this)
            r = eval(this.RadiiTextField.Text);
        end
    end
end

