function icon = makeicon(m,n,clr)
%MAKEICON Generate basic color icons.
%   ICON = MAKEICON(M,N,CLR) returns an M-by-N-by-3 icon where every pixel
%   is colored using the input color, which can be provided either as a
%   ColorSpec string in short or long form (e.g. 'blue' or 'b') or an RGB
%   triplet (e.g. [0,0,1]).

%   Copyright 2016 Matthew R. Eicholtz

    if ischar(clr)
        rgb = str2rgb(clr); %convert ColorSpec to RGB triplet
    else
        rgb = clr;
    end
    icon = zeros(m,n,3);
    icon(:,:,1) = rgb(1);
    icon(:,:,2) = rgb(2);
    icon(:,:,3) = rgb(3);
    icon = im2uint8(icon);
    
end

