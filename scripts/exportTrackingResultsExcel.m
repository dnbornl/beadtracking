%EXPORTTRACKINGRESULTSEXCEL Export tracking results to Excel.
%   This script is used for post-processing results for tracking microbeads
%   in microscopy images of mouse brain tissue. The reason this script was 
%   created is to allow a user to work with the data outside of MATLAB.
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
%==========================================================================

%% Load image and data file
filename = filenames{fileind};
I = imread(fullfile(pathname,[filename,'.tif']),'Index',1);
load(fullfile(pathname,[filename,'.mat']),'roi','tracking');

x = tracking.position;
t = tracking.time;

%% Plot stuff
figure(1);
imshow(I,[]);
hold on;
for ii=1:length(x)
    plot(x{ii}(:,1),x{ii}(:,2),'Color',ind2rgb(ii,lines(length(x))),'LineWidth',2);
end
hold off;

%% Compute average speed
V = []; %average mean speed
dt = 0.050; %sec
micrometerperpixel = 3.2088;
for ii=1:length(x)
    dx = diff(x{ii});
    v = hypot(dx(:,1),dx(:,2))*(micrometerperpixel/dt);
    V = [V; mean(v)];
end

fprintf('Average mean speed = %0.3f\n',mean(V));

%% Save data to file
xlsfile = fullfile(pathname,'tracking results.xlsx');
xlswrite(xlsfile,{filename},'Sheet1',sprintf('%s1',char(fileind+'A'-1)));
xlswrite(xlsfile,V(:),'Sheet1',sprintf('%s2',char(fileind+'A'-1)));

