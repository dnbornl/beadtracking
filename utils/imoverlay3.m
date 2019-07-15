function varargout = imoverlay3(I,mask,varargin)
%IMOVERLAY3 Visualize a sequence of images with superimposed masks.
%   IMOVERLAY3(I,MASK) generates a figure for visualizing slices of an
%   input volume with a superimposed mask. The size of both input arrays 
%   must be equal.
%
%   H = IMOVERLAY3(___) returns the figure handle as output.
%
%   IMOVERLAY3(___,Name,Value) uses additional parameter name-value pairs.
%   Valid parameters include:
%
%       'Color'         Color of the superimposed mask, given as a 1-by-3
%                       RGB vector with values in the range [0,1].
%
%                       Default: [1 0 0] (red)
%
%       'Opacity'       Scalar indicating the alpha value for the
%                       superimposed mask. Must be >=0 and <=1. A value of
%                       0 indicates full transparency, while a value of 1
%                       indicates no transparency.
%
%                       Default: 0.4
%
%       'Parent'        Handle of the parent figure to use. Can be a
%                       numeric scalar or the string 'new'.
%
%                       Default: sum(mfilename+0)
%
%       'Scale'         Scalar indicating how to resize the image. Passed
%                       as an input to IMRESIZE.
%
%                       Default: 1 (no resizing)
%
%   See also IMOVERLAY, IMOVERLAY2.

% Copyright 2016-2018 Matthew R. Eicholtz

% Default parameter values
default = struct(...
    'Color',[1 0 0],...
    'Opacity',0.4,...
    'Parent',sum(mfilename+0),...
    'Scale',1);

% Parse inputs
[clr,opacity,h,scale] = parseinputs(default,varargin{:});
assert(isequal(size(I),size(mask)),'ERROR: The input image and mask muse be the same size.');
I = imresize(I,scale,'nearest');
mask = imresize(mask,scale,'nearest');
[row,col,layers] = size(I);
cmask = bsxfun(@times,ones(row,col,3),permute(clr,[1 3 2])); %create color mask
mask = mask*opacity; %apply opacity

% Setup figure
if ishandle(h); close(h); end %close the figure if it exists
h = figure(h);
h.Visible = 'on';
h.Color = [1 1 1];
h.MenuBar = 'figure';
h.ToolBar = 'figure';
h.Resize = 'off';

marginx = 12;
marginheader = 28;
marginfooter = 12;
if layers>1; marginfooter = 40; end
pos = h.Position; %initial figure position
pos(2) = min(pos(2),100);
h.Position = [pos(1:2), col+2*marginx, row+marginheader+marginfooter];
axes('Units','pixels','Position',[marginx,marginfooter,col,row]);
if layers>1
    uicontrol(...
        'Style','slider',...
        'Callback',@updatefigure,...
        'Max',layers,...
        'Min',1,...
        'Units','pixels',...
        'Position',[0 0 h.Position(3)+2 28],...
        'SliderStep',[1/(layers-1) 1/(layers-1)],...
        'Tag','slider',...
        'Value',1);
end

% Set application-defined data
setappdata(h,'I',I);
setappdata(h,'mask',mask);

% Render the first image
image(repmat(I(:,:,1),1,1,3),'Tag','image');
hold on;
image(cmask,'Tag','mask','AlphaData',mask(:,:,1));
text(col-4,-24,sprintf('%d/%d',1,layers),'FontSize',12,'FontWeight','bold','Color','k',...
    'Interpreter','none','HorizontalAlignment','right','VerticalAlignment','top');
hold off;
axis off;

% Return the figure handle, if requested
if nargout>0
    varargout = {h};
end

end

%% Helper functions
function varargout = parseinputs(default,varargin)
%PARSEINPUTS Custom input parsing function.
    p = inputParser;
    
    p.addParameter('color',default.Color,...
        @(x) validateattributes(x,{'numeric'},{'size',[1 3],'nonempty','nonsparse','>=',0,'<=',1}));
    p.addParameter('opacity',default.Opacity,...
        @(x) validateattributes(x,{'numeric'},{'scalar','nonempty','nonsparse','>=',0,'<=',1}));
    p.addParameter('parent',default.Parent,...
        @(x) isnumeric(x)|strcmp(x,'new'));
    p.addParameter('scale',default.Scale,...
        @(x) validateattributes(x,{'numeric'},{'scalar','nonempty','nonsparse','>',0,'finite'}));
    
    p.parse(varargin{:});
    
    [clr,opacity,h,scale] = struct2vars(p.Results);
    
    if strcmp(h,'new')
        h = length(findobj('type','figure'))+1;
    end
    
    varargout = {clr,opacity,h,scale};
end
function updatefigure(obj,~)
%UPDATEFIGURE Update the figure when the slider value changes.
    ind = round(obj.Value);
    obj.Value = ind;
    
    h = obj.Parent;
    I = getappdata(h,'I');
    mask = getappdata(h,'mask');
    
    himage = findobj(h,'Tag','image');
    hmask = findobj(h,'Tag','mask');
    htext = findobj(h,'Type','text');
    
    himage.CData = repmat(I(:,:,ind),1,1,3);
    hmask.AlphaData = mask(:,:,ind);
    htext.String = sprintf('%d/%d',ind,size(I,3));
end

