%SHOWTRACKINGRESULTS Generate relevant tracking images and videos.
%   This script is the fourth in a series of scripts used to track
%   microbeads in microscopy images of mouse brain tissue.
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
%       'options'       Numerical vector indicating which images/videos to
%                       generate. Valid options include:
%
%                       1   Raw video.
%
%                       2   Video with all tracked objects overlaid.
%
%                       3   Video with one tracked object overlaid.
%
%                       4   Raw image with tracks overlaid.
%
%                       5   Speedmap showing trajectories of tracked
%                           objects with color indicating instantaneous
%                           speed.
%
%       'frames'        Either a scalar, vector, or the string 'all'
%                       indicating which frames to include in the
%                       visualization(s).
%
%       'fps'           Frame rate for VIEWING videos. Note that this is
%                       not the frame rate at which the video is written to
%                       file.
%
%       'id'            Scalar index of the tracked object to show. Only
%                       matters for option 3.
%
%       'savevideo'     Logical scalar indicating whether to save videos or
%                       not.
%
%       'saveimage'     Logical scalar indicating whether to save images or
%                       not.
%
%       ... (some parameters are not listed here, but are described below)
%
%	See also RUNBLOBDETECTION, RUNBLOBREFINEMENT, RUNKALMANTRACKING.

% Copyright 2016-2019 Matthew R. Eicholtz
clear; clc; %close all;

% ================== MODIFY THESE PARAMETERS AS NEEDED ====================
pathname = fullfile(beadtracking.path,'data');

filenames = {...
    '1784 cont';
    '1861 hemi-1';
    '1861 hemi-2';
    '1925 cont-4'};

fileind = 4;

options = 5;
%   1   Raw video
%   2   Playback video with all tracked beads overlayed
%   3   Playback video with one tracked bead overlayed
%   4   Raw image with tracks overlayed
%   5   Speedmap showing trajectories of tracked beads with color
%       indicating instantaneous speed

frames = 'all';
fps = 8;
id = 6;
maxnumpoints = 5; %maximum number of points to show for each track at any given time

flip180 = false; %should the image be rotated 180 degrees
crange = [0 600]; %colorbar range
beta = 0.4; %for brightening the image (Tae-Yeon said they looked too dark)

useroi = false; %whether to use roi or not
sz = []; %[width height] of the bounding box, centered on ROI

addtimer = true; %add timer to lower right corner of video

savevideo = false; %logical determining whether to save videos to file
saveimage = false; %logical determining whether to save images to file

dt = 0.050; %elapsed time per frame, in seconds
timeconstant = datenum([0 0 0 0 0 dt]);
micrometerperpixel = 3.2088;
%==========================================================================

for ii=fileind
    % Load image sequence
    imgfile = fullfile(pathname,[filenames{ii},'.tif']);
    info = imfinfo(imgfile);
    if strcmp(frames,'all')
        frames = 1:length(info);
    end
    I = imframe(imgfile,frames,'class','uint8');
    [m,n,p,q] = size(I); %dimensions of the raw images
    
    % Load data
    datafile = fullfile(pathname,[filenames{ii},'.mat']);
    load(datafile,'roi','detection','refinement','tracking');
    
    % Compute bounding box around region-of-interest
    if ~exist('roi','var') || ~useroi
        roi.mask = true(m,n);
        bb = [1 1 n-1, m-1];
    else
        stats = regionprops(roi.mask,'BoundingBox');
        bb = floor(stats.BoundingBox);
    end
    if ~isempty(sz) %force bounding box size to be larger
        bb = [bb(1:2)-(sz-bb(3:4))/2, sz-1];
        extraspace = [n,m]-(bb(1:2)+bb(3:4));
        shiftbb = extraspace<0; %do we need to shift the bounding box because of image dimensions?
        if any(shiftbb)
            bb([shiftbb false false]) = bb([shiftbb false false])-abs(extraspace(shiftbb));
        end
    end
    
    % Store cropped version of each image
    J = zeros(bb(4)+1,bb(3)+1,p,q,'uint8');
    for jj=1:q
        J(:,:,:,jj) = imcrop(I(:,:,:,jj),bb);
    end
    [mm,nn,pp,qq] = size(J); %dimensions of the cropped images
    
    % Generate visualizations based on user-specified options
    if any(options==1) %raw video
        if savevideo
            video = VideoWriter(fullfile(pathname,[filenames{ii} ' raw video.avi']));
            video.FrameRate = 20;
            open(video);
        end
        
        figure(1); clf;
        himage = imshow(J(:,:,:,1),[],'InitialMag','fit');
        colormap gray
        brighten(beta);
        if addtimer
            htext = text(nn-75,mm-19,datestr(0,'MM:SS.FFF'),...
                'FontWeight','normal',...
                'FontSize',14,...
                'Color','w');
        end
        
        for jj=1:q
            tic;
            if flip180
                himage.CData = flipud(J(:,:,:,jj));
            else
                himage.CData = J(:,:,:,jj);
            end
            if addtimer; htext.String = datestr((jj-1)*timeconstant,'MM:SS.FFF'); end
            if savevideo; writeVideo(video,getframe); end
            pause(1/fps-toc);
        end
        
        if savevideo; close(video); end
    end
    
    if any(options==2) %playback video with all tracked beads overlayed
        % Setup video file if it is going to be saved
        if savevideo
            video = VideoWriter(fullfile(pathname,[filenames{ii} ' short tracks.avi']));
            video.FrameRate = 20;
            open(video);
        end
        
        % Setup figure
        figure(2); clf;
        himage = imshow(J(:,:,:,1),[],'InitialMag','fit');
        colormap gray
        brighten(beta);
        
        % Add timer to video, if requested
        if addtimer
            htext = text(nn-75,mm-19,datestr(0,'MM:SS.FFF'),...
                'FontWeight','normal',...
                'FontSize',14,...
                'Color','w');
        end
        
        % Add animated lines for beads
        numbeads = length(tracking.position); %number of beads
        for jj=1:numbeads
            hbead(jj) = animatedline(...
                'Color',ind2rgb(jj,lines(numbeads)),...
                'LineWidth',2,...
                'Marker','none',...
                'MaximumNumPoints',maxnumpoints,...
                'Parent',gca);
        end
        
        % Iterate over frames
        for jj=1:q
            frame = frames(jj);
            tic;
            if flip180
                himage.CData = flipud(J(:,:,:,jj));
            else
                himage.CData = J(:,:,:,jj);
            end
            if addtimer; htext.String = datestr((frame-1)*timeconstant,'MM:SS.FFF'); end
            for kk=find(cellfun(@(x) any(x==frame),tracking.time))'
                ind = tracking.time{kk}==frame;
                x = tracking.position{kk}(ind,1)-bb(1)+1;
                y = tracking.position{kk}(ind,2)-bb(2)+1;
                if flip180
                    y = bb(4)-y+1;
                end
                addpoints(hbead(kk),x,y);
            end
            
            for kk=find(cellfun(@(x) x(end)<frame,tracking.time))'
                [x,y] = getpoints(hbead(kk));
                if ~isempty(x)
                    addpoints(hbead(kk),x(end),y(end));
                end
            end
            if savevideo; writeVideo(video,getframe); end
            pause(1/fps-toc);
        end
        
        if savevideo; close(video); end
    end
    
    if any(options==3) %playback video with one tracked bead overlayed
        if savevideo
            video = VideoWriter(fullfile(pathname,[filenames{ii} ' short track.avi']));
            video.FrameRate = 20;
            open(video);
        end
        
        figure(3); clf;
        himage = imshow(J(:,:,:,1),[],'InitialMag','fit');
        colormap gray
        brighten(beta);
        if addtimer
            htext = text(nn-75,mm-19,datestr(0,'MM:SS.FFF'),...
                'FontWeight','normal',...
                'FontSize',14,...
                'Color','w');
        end
        
        hbead = animatedline(...
            'Color',ind2rgb(id,lines(length(tracking.position))),...
            'LineWidth',2,...
            'Marker','none',...
            'MaximumNumPoints',maxnumpoints,...
            'Parent',gca);
        
        x = tracking.position{id};
        t = tracking.time{id};
        for jj=t(1):t(end)
%             if jj==(t(1)+2); pause; end
            tic;
            if flip180
                himage.CData = flipud(J(:,:,:,jj));
            else
                himage.CData = J(:,:,:,jj);
            end
            if addtimer; htext.String = datestr((jj-1)*timeconstant,'MM:SS.FFF'); end
            
            if any(t==jj)
                addpoints(hbead,x(t==jj,1),x(t==jj,2));
            end
            if savevideo; writeVideo(video,getframe); end
            pause(1/fps-toc);
        end
        
        if savevideo; close(video); end
    end
    
    if any(options==4) %raw image with tracks overlayed
        x = tracking.position;
        
        figure(4);
        imshow(I(:,:,:,1),[],'InitialMag','fit');
        colormap gray
        brighten(beta);
        hold on;
        for jj=1:length(x)
            plot(x{jj}(:,1),x{jj}(:,2),'Color',ind2rgb(jj,lines(length(x))),'LineWidth',2);
        end
        hold off;
    end
    
    if any(options==5) %speedmap
        xy = tracking.position;
        marginx = 80;
        marginy = 35;
        
        figure(5); clf;
%         imshow(repmat(I(:,:,:,1),1,1,3));
        imshow(repmat(ones(mm+marginy,nn+marginx),1,1,3),[],'InitialMag','fit'); %white background
        hold on;
        % plot(xy{1}(:,1),xy{1}(:,2),'LineWidth',2);
        
        for jj=1:length(xy)
            x = xy{jj}(:,1)'-bb(1)+1;
            y = xy{jj}(:,2)'-bb(2)+1+marginy;
            if flip180
                y = bb(4)-y+2;
            end
            z = zeros(size(x));
            s = hypot(diff(x),diff(y))*(micrometerperpixel/dt);
            col = [s(1), s];  % This is the color, vary with x in this case.
            surface([x;x],[y;y],[z;z],[col;col],...
                    'facecol','no',...
                    'edgecol','interp',...
                    'linew',2);
        end
        caxis(crange);
        hold off;
        colorbar('east','FontSize',14,'FontWeight','normal','Color','k');
        text(n-170,13,'Speed (\it{{\fontsize{18}\mu}m/s})','FontWeight','normal','FontSize',14,'Color','k');
        
        if saveimage
            print(fullfile(pathname,[filenames{ii} ' speedmap.png']),'-dpng');
        end
    end

    %% Show histogram fit of track velocity
%     figure;
%     hold on;
%     for jj=1:length(v)
%         h = histfit(v{jj},10,'kernel');
%         delete(h(1));
%     end
%     hold off;
end

return

%% Compute heat map of average instantaneous speed
x = cell2mat(cellfun(@(x) x(2:end,:), X,'uni',0));
v = Vavg;
% hmap = zeros(m,n);
hmap = accumarray(x(:,[2 1]),v,[m,n],@mean,0);
figure; imagesc(hmap);

%% Compare to optical flow
optflow = opticalFlowHS();
hmap2 = zeros(m,n,q);
for ii=1:q
    fprintf('Computing optical flow: %d\n',ii);
    flow = estimateFlow(optflow,I(:,:,:,ii));
    hmap2(:,:,ii) = double(flow.Magnitude);
end

%% Compare optical flow heat map to tracked beads heat map
stats = regionprops(roi.mask);
hmap_roi = imcrop(mean(hmap,3),stats.BoundingBox);
hmap2_roi = imcrop(mean(hmap2,3),stats.BoundingBox);

figure; imagesc(hmap_roi);
axis image; axis off;
colorbar;

figure; imagesc(hmap2_roi);
axis image; axis off;
colorbar;

