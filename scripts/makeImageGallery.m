%MAKEIMAGEGALLERY Generate gallery of images showing tracking over time.
%   This script is used for post-processing results for tracking microbeads
%   in microscopy images of mouse brain tissue. The reason this script was 
%   created is to visualize tracking in a static montage, which can be 
%   published in a paper, whereas videos would be included as supplementary
%   material.
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
%       'saveresults'   Logical scalar indicating whether to save the
%                       results to file. If true, each image in the gallery
%                       is written to file based on the change in time
%                       between frames. That is, the first frame is called
%                       '<filename> gallery t000.png', and a frame 1.5
%                       seconds later would be called '... t150.png'.
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

fileind = 4;

frames = 185:5:205;
% frames = 255:5:275; 185:5:205; % 1925
% frames = 110:5:130; 78:5:98; % 1861 hemi-1

whichbeads = [2 3 4]; % for 1925 cont-4
% whichbeads = [2 3 5]; % for 1861 hemi-1

bb = [110 1 159 119]; % bounding box [95 8 159 119]

beta = 0; % for brightening the image (Tae-Yeon said they looked too dark)
scale = 2; % for resizing the image
markersize = 300; % size of markers around beads
linewidth = 2; % line width of markers around beads

dt = 0.050; % elapsed time per frame, in seconds
micrometerperpixel = 3.2088;

addtimer = true; % add timer to lower right corner of video

saveresults = false; % logical determining whether to save images to file
%==========================================================================

for ii=fileind
    % Load image sequence
    imgfile = fullfile(pathname,[filenames{ii},'.tif']);
    info = imfinfo(imgfile);
    if strcmp(frames,'all')
        frames = 1:length(info);
    end
    I = imframe(imgfile,'Index',frames,'Class','uint8');
    [m,n,p,q] = size(I); %dimensions of the raw images
    
    % Store cropped version of each image
    J = zeros(bb(4)+1,bb(3)+1,p,q,'uint8');
    for jj=1:q
        J(:,:,:,jj) = imcrop(I(:,:,:,jj),bb);
    end
    J = imresize(J,scale);
    [mm,nn,~,~] = size(J); %dimensions of the cropped images
    
    % Load tracking data
    datafile = fullfile(pathname,[filenames{ii},'.mat']);
    load(datafile,'tracking');
    x = tracking.position;
    t = tracking.time;
    checktime = cellfun(@(x) ismember(x,frames),t,'uni',0);
    relevant = cellfun(@(x,t) sum(inpolygon(x(t,1), x(t,2),bb(1)+[0,bb(3)],bb(2)+[0,bb(4)]))>2,x,checktime);
    
    x = x(relevant);
    t = t(relevant);
    
    if ~isempty(whichbeads); x = x(whichbeads); t = t(whichbeads); end
    
    x = cellfun(@(x) bsxfun(@minus,x,bb(1:2)-1),x,'uni',0);
    x = cellfun(@(x) x*scale,x,'uni',0);
    clrs = [...
        0.8627 0.0784 0.0784;
        1 0.8431 0;
        0 0.4471 0.7412];
%     clrs = lines(length(x));
    
    % Build gallery
    for jj=1:q
        timej = (frames(jj)-frames(1))*dt;
        
        % Create figure
        figure(jj);
        K = J(:,:,:,jj);
        K = imadjust(K,stretchlim(K,[0.5 0.999]),[]);
        himage = imshow(K);
        brighten(beta);
        set(gcf,'NumberTitle','off',...
            'Name',sprintf('%0.2f',timej));
        
        % Add circles for tracked beads
        hold on;
        for kk=1:length(x)
            ind = find(t{kk}==frames(jj));
            if ~isempty(ind)
                scatter(x{kk}(ind,1),x{kk}(ind,2),markersize,clrs(kk,:),'LineWidth',linewidth);
            end
        end
        hold off;
        
        % Save image, if desired
        if saveresults
            filename = sprintf('%s gallery t%03d.png',filenames{ii},round(timej*100));
            print(fullfile(pathname,filename),'-dpng','-r0');
        end
    end
end

