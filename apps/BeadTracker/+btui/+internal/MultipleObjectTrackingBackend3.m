classdef MultipleObjectTrackingBackend < handle
%MULTIPLEOBJECTTRACKINGBACKEND Class containing data and methods for
%multiple object tracking app.

%   Copyright 2016 Matthew R. Eicholtz

    properties
        ImageSequence
        
        CurrentFrame
        StartFrame
        EndFrame
        
        % Cache mask when opening a new tab for 'Cancel' or for 'Reset'
        % after tracking
        InitialMask
        
        % Cache mask loaded into Refine Tab
        CleanupMask
        
        % Cache mask after imfill/imclearborder to prevent delays in slider
        % reaction
        CleanedMask
        
        % Cache connected components on CleanedMask
        CC
        
        % View controls
        hScrollPanel
        hfigure
        
        ROIColor
        ROIOpacity
        ROIThickness
        
        OpticalFlowAlg
        OpticalFlowDecimation
        OpticalFlowScale
        
        OpticalFlowHSContainer
        OpticalFlowLKContainer
    end
    
    properties (SetObservable=true)
        Mask
        ROI
        OpticalFlow
        FPS
    end
    
    properties (Dependent=true,SetAccess=private)
        NumFrames
        ImageSize
        AlphaData
        CurrentImage
        PreviousImage
        
        QuiverInput
    end
    
    properties (Access=private)
        ShowROI
        ShowOpticalFlow
        ShowDetection
        ShowTracking
    end
    
    %======================================================================
    %
    % Defaults
    % ------------
    % Define relevant default parameter values for properties stored in the
    % backend such as ROI mask, frame rate, etc.
    %
    %======================================================================
    properties (Dependent=true,SetAccess=private)
        DefaultROI
        DefaultOpticalFlow
    end
    properties (Constant,Access=private)
        DefaultROIColor                 = [1 0 0];
        DefaultROIOpacity               = 70;
        DefaultROIThickness             = 1;
        
        DefaultOpticalFlowAlg           = 'none';
        DefaultOpticalFlowDecimation    = 10;
        DefaultOpticalFlowScale         = 10;
    end
    
    %======================================================================
    %
    % Public methods
    %
    %======================================================================
    methods
        function this = MultipleObjectTrackingBackend(im)
            % Parse inputs
            if nargin==0
                im = [];
            end
            this.ImageSequence = im;
            [m,n,~,~] = size(im);
            
            % Defaults
            this.CurrentFrame       = 1;
            this.StartFrame         = 1;
            this.EndFrame           = this.NumFrames;
            this.FPS                = 20;
            
            this.Mask               = false(m,n);
            this.InitialMask        = this.Mask;
            this.CleanupMask        = this.Mask;
            this.CleanedMask        = this.Mask;
            
            this.ROI                = this.DefaultROI;
            this.ROIColor           = this.DefaultROIColor;
            this.ROIOpacity         = this.DefaultROIOpacity;
            this.ROIThickness       = this.DefaultROIThickness;
            
            this.OpticalFlow            = this.DefaultOpticalFlow;
            this.OpticalFlowAlg         = this.DefaultOpticalFlowAlg;
            this.OpticalFlowDecimation  = this.DefaultOpticalFlowDecimation;
            this.OpticalFlowScale       = this.DefaultOpticalFlowScale;
            this.OpticalFlowHSContainer = opticalFlowHS();
            this.OpticalFlowLKContainer = opticalFlowLK();
            
            this.ShowROI            = false;
            this.ShowOpticalFlow    = false;
            this.ShowDetection      = false;
            this.ShowTracking       = false;
        end
        function delete(this)
            % In graphics version 1, the figure may still be alive after
            % the destruction of the Backend class. So, we explicitly
            % delete it. We need to check that the figure handle is valid
            % before destroying it.
            if ~isempty(this.hfigure) && ishandle(this.hfigure)
                delete(this.hfigure);
            end
        end
    end
    
    %======================================================================
    %
    % Optical flow methods
    %
    %====================================================================== 
    methods
        function updateOpticalFlow(this)
            switch this.OpticalFlowAlg
                case 'none'
                    this.OpticalFlow = this.DefaultOpticalFlow;
                    
                case 'horn-schunck'
                    estimateFlow(this.OpticalFlowHSContainer,this.PreviousImage);
                    this.OpticalFlow = estimateFlow(this.OpticalFlowHSContainer,this.CurrentImage);

                case 'lucas-kanade'
                    estimateFlow(this.OpticalFlowLKContainer,this.PreviousImage);
                    this.OpticalFlow = estimateFlow(this.OpticalFlowLKContainer,this.CurrentImage);
            end
        end
    end
    
    %======================================================================
    %
    % Set/Get property methods
    %
    %======================================================================
    methods
        %******************************************************************
        % Get
        %******************************************************************
        function I = get.CurrentImage(this)
            I = this.ImageSequence(:,:,:,this.CurrentFrame);
        end
        function I = get.PreviousImage(this)
            ind = max(1,this.CurrentFrame-1);
            I = this.ImageSequence(:,:,:,ind);
        end
        function mask = get.DefaultROI(this)
            mask = true(this.ImageSize);
        end
        function opticflow = get.DefaultOpticalFlow(this)
            opticflow = opticalFlow(zeros(this.ImageSize),zeros(this.ImageSize));
        end
        function sz = get.ImageSize(this)
            [m,n,~,~] = size(this.ImageSequence);
            sz = [m,n];
        end
        function N = get.NumFrames(this)
            N = size(this.ImageSequence,4);
        end
        function A = get.AlphaData(this)
            se = strel('disk',this.ROIThickness,8);
            
            mask = bwperim(imdilate(this.ROI,se));
            mask = imdilate(mask,se);
            
            A = ones(size(mask));
            A(mask) = 1-this.ROIOpacity/100;
        end
        function X = get.QuiverInput(this)
            offset = 1; % this could be user input
            
            % Only look at region of interest.
            Vx = this.OpticalFlow.Vx;
            Vx(~this.ROI) = 0;
            Vy = this.OpticalFlow.Vy;
            Vy(~this.ROI) = 0;
            
            % Only look at significant magnitudes
            mask = this.OpticalFlow.Magnitude>=0.05*max(this.OpticalFlow.Magnitude(:));
            Vx(~mask) = 0;
            Vy(~mask) = 0;
            
            [row,col] = size(Vx);
            rowind = offset:this.OpticalFlowDecimation:(row-offset+1);   
            colind = offset:this.OpticalFlowDecimation:(col-offset+1);   
            [x,y] = meshgrid(colind,rowind);
            
            ind = sub2ind([row,col],y(:),x(:));
            u = Vx(ind);
            v = Vy(ind);
            u = u.*this.OpticalFlowScale;
            v = v.*this.OpticalFlowScale;
 
            mask = u>0 | v>0;
            X = [x(mask),y(mask),u(mask),v(mask)];
        end
    end
end

