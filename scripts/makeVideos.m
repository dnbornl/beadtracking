%MAKEVIDEOS
%   The purpose of this script is to create videos that can be used as
%   supplementary material in research publications.
%
%   Before running the script, the user should modify the parameters listed
%   at the top, including:
%
%       'pathname'      String indicating the directory in which the image
%                       sequence is stored.
%
%       'filenames'     Cell array of filenames to look at in the given
%                       directory. This approach is used so that you can
%                       quickly switch between files without having to
%                       retype the (sometimes complicated) strings.
%                       ***IMPORTANT: Do not include the file extension 
%                       (.tif is assumed)!***
%
%       'fileind'       Scalar or vector of indices indicating which files 
%                       to run in the current execution of the code.
%
%       'frames'        Either a scalar, vector, or the string 'all'
%                       indicating which frames to include in the
%                       visualization(s).
%
%       'videotype'     Scalar indicating which type of video to make.
%                       
%                       1 	raw image sequence with timer included
%                       2 	image sequence with time and tracked beads close to loading area
%                       3   image sequence with time and tracked beads far from loading zrea
%                       4   detections with stationary beads
%                       5   detections without stationary beads
%
%       ... (some parameters are not listed here, but are described below)

% Copyright 2016-2019 Matthew R. Eicholtz
cleanup;

% ================== MODIFY THESE PARAMETERS AS NEEDED ====================
pathname = fullfile(beadtracking.path,'data');

filenames = {...
    '1784 cont';
    '1861 hemi-1';
    '1861 hemi-2';
    '1925 cont-4'};

% Image properties
fileind = 4;
frames = 'all';
crop = []; %rectangle to crop (e.g. [155 100 400 300])

% Video properties
videotype = 5;
videofile = fullfile(pathname,'1784 cont.avi');
framerate = 20; %frames per second (in the output video)
dt = 0.050; %elapsed time per frame, in seconds
savevideo = false; % logical scalar that determines whether the video gets saved or not

%==========================================================================

%% Load relevant data
imgfile = fullfile(pathname,[filenames{fileind},'.tif']);
datafile = fullfile(pathname,[filenames{fileind},'.mat']);

info = imfinfo(imgfile);
I = imframe(imgfile,frames,'class','uint8');
[m,n,p,q] = size(I);

load(datafile,'roi','detection','refinement','tracking');

%% Create video
if savevideo
    video = VideoWriter(videofile);
    video.FrameRate = framerate;
    open(video);
end
switch videotype
    case 1 % show raw image sequence with a timer in the bottom-right corner
        figure(sum(mfilename+0));
        
        timeconstant = datenum([0 0 0 0 0 dt]);
        for ii=1:q
            fprintf('Frame %d of %d',ii,q);
            I = imread(imgfile,'Index',ii,'Info',info);
            if ~isempty(crop)
                J = imcrop(I,crop-[0 0 1 1]);
            else
                J = I;
            end
            [y,x,~] = size(J);
            imshow(J,[],'InitialMag','fit');
            text(x-75,y-19,datestr((ii-1)*timeconstant,'MM:SS.FFF'),'FontWeight','normal','FontSize',14,'Color','w');
            pause(0.05);
            if savevideo
                fprintf('...writing to file\n');
                writeVideo(video,getframe);
            else
                fprintf('\n');
            end
        end
        
        
    case 2 % show image sequence with time and tracked beads near loading area
        
        %%% FUTURE WORK %%%
        
    case 4 % show detections with stationary beads
        figure(sum(mfilename+0));
        
        timeconstant = datenum([0 0 0 0 0 dt]);
        for ii=1:q
            fprintf('Frame %d of %d',ii,q);
            I = imread(imgfile,'Index',ii,'Info',info);
            stats = regionprops(roi.mask,'BoundingBox');
            bb = stats.BoundingBox;
            
            offset = 8;
            scale = 1;
            
            J = imcrop(I,bb+[0 0 offset offset]);
            J = imresize(J,scale);
            [y,x,~] = size(J);
            imshow(J,[],'InitialMag','fit');
            text(x-75,y-19,datestr((ii-1)*timeconstant,'MM:SS.FFF'),'FontWeight','normal','FontSize',14,'Color','w');
            
            % Show detections
            X = detection.blobs{ii};
            mask = roi.mask(sub2ind(size(roi.mask),X(:,2),X(:,1)));
            X(~mask,:) = [];
            
            X(:,1) = X(:,1)-bb(1);
            X(:,2) = X(:,2)-bb(2);
            
            X = X*scale;
            
            theta = (0:2:360)'*pi/180;
            x = bsxfun(@times,X(:,3)',cos(theta));
            x = bsxfun(@plus,x,X(:,1)');
            
            y = bsxfun(@times,X(:,3)',sin(theta));
            y = bsxfun(@plus,y,X(:,2)');

            v = [x(:),y(:)]; %vertices
            f = reshape(1:numel(x),[],size(X,1))'; %faces
            
            hpatch = patch('Faces',f,'Vertices',v);
            hpatch.FaceColor = [0.9294    0.6941    0.1255];
            hpatch.EdgeColor = max(0,[0.9294    0.6941    0.1255]-0.2);
            hpatch.FaceAlpha = 0.2;
            hpatch.LineWidth = 1;
            
            pause(0.05);
            if savevideo
                fprintf('...writing to file\n');
                writeVideo(video,getframe);
            else
                fprintf('\n');
            end
        end
        
    case 5 % show detections without stationary beads
        figure(sum(mfilename+0));
        
        timeconstant = datenum([0 0 0 0 0 dt]);
        for ii=1:q
            fprintf('Frame %d of %d',ii,q);
            I = imread(imgfile,'Index',ii,'Info',info);
            stats = regionprops(roi.mask,'BoundingBox');
            bb = stats.BoundingBox;
            
            offset = 8;
            scale = 1;
            
            J = imcrop(I,bb+[0 0 offset offset]);
            J = imresize(J,scale);
            [y,x,~] = size(J);
            imshow(J,[],'InitialMag','fit');
            text(x-75,y-19,datestr((ii-1)*timeconstant,'MM:SS.FFF'),'FontWeight','normal','FontSize',14,'Color','w');
            
            % Show detections
            X = refinement.blobs{ii};
            mask = roi.mask(sub2ind(size(roi.mask),X(:,2),X(:,1)));
            X(~mask,:) = [];
            
            X(:,1) = X(:,1)-bb(1);
            X(:,2) = X(:,2)-bb(2);
            
            X = X*scale;
            
            theta = (0:2:360)'*pi/180;
            x = bsxfun(@times,X(:,3)',cos(theta));
            x = bsxfun(@plus,x,X(:,1)');
            
            y = bsxfun(@times,X(:,3)',sin(theta));
            y = bsxfun(@plus,y,X(:,2)');

            v = [x(:),y(:)]; %vertices
            f = reshape(1:numel(x),[],size(X,1))'; %faces
            
            hpatch = patch('Faces',f,'Vertices',v);
            hpatch.FaceColor = [0.9294    0.6941    0.1255];
            hpatch.EdgeColor = max(0,[0.9294    0.6941    0.1255]-0.2);
            hpatch.FaceAlpha = 0.2;
            hpatch.LineWidth = 1;
            
            pause(0.05);
            if savevideo
                fprintf('...writing to file\n');
                writeVideo(video,getframe);
            else
                fprintf('\n');
            end
        end
        
    otherwise
        error('Unrecognized value for videotype. Check inputs.');
end

if savevideo; close(video); end

