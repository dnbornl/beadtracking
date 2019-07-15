function status(varargin)
%STATUS Print status update to Command Window.

% Copyright 2016 Matthew R. Eicholtz

% Get timestamp
time = datestr(now,'dd-mmm-yyyy HH:MM:SS.FFF');

% Get name
mystack = dbstack;
if length(mystack)==1
    name = sprintf('\b');
else
    name = sprintf('[%s]',mystack(2).name);
end

% Get file identifier, if provided
fid = varargin{1};
if ~(isnumeric(fid) && fid>0 && isequal(fid,round(fid)))
    fid = 1;
    args = varargin;
else
    args = varargin(2:end);
end

% Make the message
msg = sprintf(args{:});

% Print the status
asterisk = strfind(msg,'*');
if isempty(asterisk)
    fprintf(fid,'%s %s %s\n',time,name,msg);
elseif asterisk==1
    fprintf(fid,'%s\n',msg(2:end));
elseif asterisk==length(msg)
    fprintf(fid,'%s %s %s',time,name,msg(1:end-1));
end

end

