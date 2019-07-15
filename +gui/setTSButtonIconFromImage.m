function setTSButtonIconFromImage(obj,img)
%GUI.SETTSBUTTONICONFROMIMAGE Use custom image for TSButton icon.
%   GUI.SETTSBUTTONICONFROMIMAGE(OBJ,IMG) sets the icon of the TSButton OBJ
%   to the input image. There is no direct support for setting a TSButton 
%   icon from a image buffer in memory in the toolstrip API.

% Copyright 2016-2019 Matthew R. Eicholtz

overlayColorButtonJavaPeer = obj.Peer;
javaImage = im2java(img);
icon = javax.swing.ImageIcon(javaImage);
overlayColorButtonJavaPeer.setIcon(icon);

end

