%EXPLOREFILTERRESPONSE
%   The purpose of this script is to explore how LoG filter response varies
%   with blob size.
%
%   I observed at some point that running 20 filters on an image (to allow 
%   for 20 different blob sizes) was slower than running 10 filters for 
%   example. In the ideal case, I'd want to only run 1 filter, but in 
%   theory, I would only be able to find one blob size. I proposed to Derek
%   the following question: What if I could use 1 filter to extract blobs 
%   of varying sizes? Could I find blobs of larger size? Could I find blobs
%   of smaller size? This script was born out of that conversation.

% Copyright 2016-2019 Matthew R. Eicholtz
cleanup;

margin = 5;
radii = 1:10;

rmax = max(radii);
N = length(radii);

bw = zeros(2*rmax+2*margin, 2*rmax*N+(N+1)*margin);

for ii=1:N
    x = margin*ii+2*rmax*(ii-1)+rmax;
    y = margin+rmax;
    bw = insertShape(bw,'FilledCircle',[x, y, radii(ii)],'Color','w','Opacity',1);
end
bw = rgb2gray(bw);

figure(1); 
imshow(bw);

R = radii(round(end/2));
R = 10;
sigma = R/sqrt(2);
hsize = 2*ceil(2*sigma)+1;
h = fspecial('log',hsize,sigma);

f = imfilter(bw,h,'replicate','conv');
f = f-sum(h(h<0));
f = f/sum(sum(abs(h)));

figure(2);
imshow(f,[]);
colormap(parula);

figure(3);
imshow(imregionalmin(f));
