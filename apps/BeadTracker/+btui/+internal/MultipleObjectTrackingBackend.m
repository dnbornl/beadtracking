classdef MultipleObjectTrackingBackend < handle
%BTUI.INTERNAL.MULTIPLEOBJECTTRACKINGBACKEND Class containing data and 
%methods for multiple object tracking app.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        ImageSequence
        
        CurrentFrame
        StartFrame
        EndFrame
        
        Detections
        
        hScrollPanel
        hfigure
    end
    properties (SetObservable=true)
        ROI
    end
    properties (Dependent=true,SetAccess=private)
        NumFrames
        ImageSize
        CurrentImage
        PreviousImage
        
        QuiverInput
    end
    
    methods % public
        function this = MultipleObjectTrackingBackend(im)
            % Parse inputs
            if nargin==0
                im = [];
            end
            this.ImageSequence = im;
            
            % Defaults
            this.CurrentFrame   = 1;
            this.StartFrame   	= 1;
            this.EndFrame   	= this.NumFrames;
            this.Detections   	= [];
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
    methods % set/get
        function I = get.CurrentImage(this)
            I = this.ImageSequence(:,:,:,this.CurrentFrame);
        end
        function I = get.PreviousImage(this)
            ind = max(1,this.CurrentFrame-1);
            I = this.ImageSequence(:,:,:,ind);
        end
        function sz = get.ImageSize(this)
            [m,n,~,~] = size(this.ImageSequence);
            sz = [m,n];
        end
        function N = get.NumFrames(this)
            N = size(this.ImageSequence,4);
        end
    end
end

