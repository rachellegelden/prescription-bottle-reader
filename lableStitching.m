%run('VLFEATROOT/toolbox/vl_setup')
function [] = lableStitching()
clear;clc;close all;
cellSize = 4;
lastImg = 8;
%load image



%load All images
for i = 1:lastImg
    imgs(i).rgbImg = loadImage(strcat('images/black-background/bottle',int2str(i),'.jpeg'));
    imgs(i).title = strcat('bottle',int2str(i),'.jpg');
end
%Normalize them all to be the same rotation and orientation.
imgs = normalizeImageSet(imgs);

%unmap the cylinder to a flat flat surface
for i = 1:length(imgs)
    imgs(i).grayImg = correctImage(imgs(i));
    
end

imgList(1).grayImg = imgs(1).grayImg;
imgGradient = vl_hog(im2single(imgList(1).grayImg), cellSize) ;

imgList(1).gradient = imgGradient;
imgList(1).weight = -1;
imgList(1).seq = [1];
imgList(1).shift =[0];


compare = imgList(1);
for i = 2:lastImg
    last = length(imgList);
    grayImg = imgs(i).grayImg;
    imgGradient = vl_hog(im2single(grayImg), cellSize) ;

    additiveStuct.imgNum = i;
    additiveStuct.grayImg = grayImg;
    additiveStuct.gradient = imgGradient;
    
    [out] = compareImages(compare, additiveStuct);
    if isstruct(out)
        imgList(length(imgList)+1) = out;
        compare = out;
    end
    
end



figure, imshow(imgList(end).grayImg,[]);

%TEXT DETECTION
stitched_image = imgList(end).grayImg;                                  %get stitched image
%figure, imshow(stitched_image, []), title('stitched image');
stitched_image = uint8(stitched_image);
%figure, imshow(stitched_image, []), title('stitched image uint8');
binarized = imbinarize(stitched_image, 0.39);                           %threshold and convert to binary
    
%figure, imshow(binarized, []), title('binarized');  
    
ocrResults = ocr(binarized);                                            %get OCR object
    
text = ocrResults.Text;                                                 %get text from OCR object
disp('text: ');
disp(text);                                                             %display to console
    
fileID = fopen('textDetected.txt','wt');                                %write to file
fprintf(fileID, '%s', text);
fclose(fileID);

end

%weighting fuction
%finds the weight for one line up
function [weight] = computeWeight(st, vecSet1, vecSet2)
[~, n1,~] = size(vecSet1);
[m2, n2,~] = size(vecSet2);

w = 0;


loc = (st-1);
if loc + n2 == n1
    Aend = n1;
    Bend = n2;
elseif loc + n2 < n1
    Aend = loc + n2;
    Bend = n2;
else %loc + n2 > n1
    Aend = n1;
    Bend = n1 - loc;
end

%add weight to if for every block in the second image that is not alinged
%in the first image
if Bend < n2
    w = w + ((n2-Bend)*m2)*3.395;
end

%compare the overlab vectors
try
map = abs(vecSet1(:, st : Aend, :) - vecSet2(:,1 : Bend,:));
catch
    error(strcat('st ', int2str(st), ', vect2End ', int2str(n2)))
end
weight = sum(map,'all') + w;
end


function [out] = compareImages(baseImg, additiveStruct)
cellSize = 4;
%adding the dynamic multi image system
%must have begging and end images is it
%compare each image and save best match and weight.
%select best weight at end.
weightArray = buildWeight(baseImg.gradient, additiveStruct.gradient);
minWeight = min(weightArray(weightArray >= 0));


[shift] = find(weightArray == minWeight);




%compute the ammount we have to shift the second image by
[~,n2,~] = size(baseImg.grayImg);
[~,mappedN,~] = size(baseImg.gradient);
%maps the HoG shift location to the pixel location 
newShift = round((shift -1)*(n2/mappedN));


%found best location else failed to find best location. 
%as the shift is the last location of the matrix.
[~,n] = size(additiveStruct.grayImg);


%if the stitch is not the first or last pixel, then stitch them together
if shift ~= mappedN && shift ~= 1
    %find centerpoint of overlap
    overLap = round((n2 - newShift)/2);
    
    %clip image1 and add image2 next to each other at overlap center point.
    c1 = baseImg.grayImg(:,1:newShift + overLap,:);
    c2 = additiveStruct.grayImg(:,overLap:n,:);
    c = cat(2, c1, c2);

    grayImg = c;
    %get HoG of new image.
    gradient = vl_hog(im2single(grayImg), cellSize) ;
    
    stuct.grayImg = grayImg; 
    stuct.gradient = gradient;
    stuct.weight = baseImg.weight + minWeight;
    
    stuct.seq = [baseImg.seq, additiveStruct.imgNum];
    stuct.shift = [baseImg.shift, shift];
    
    out = stuct;
    return
else
    %if failled return -1
    out = -1;
    return
end
end



function [dpWeight] = buildWeight(vecSet1, vecSet2)
[~,n1, ~] = size(vecSet1);
[~,n2, ~] = size(vecSet2);

dpWeight = ones(1,n1)*(-1);


%k shitfs image over by 1
%ends up shifting across the x-axis
    for k = abs(n1-n2)+1:n1
        dpWeight(k) = computeWeight(k, vecSet1, vecSet2);
    end
end

function [IM] = loadImage(imgPath)
%loadImage function rotates jpg to be the correct orientation.
%as matlab does not read all properties from images.

IM = imread(imgPath);
info = imfinfo(imgPath);
if isfield(info,'Orientation')
   orient = info(1).Orientation;
   switch orient
     case 1
        %normal, leave the data alone
     case 2
        IM = IM(:,end:-1:1,:);         %right to left
     case 3
        IM = IM(end:-1:1,end:-1:1,:);  %180 degree rotation
     case 4
        IM = IM(end:-1:1,:,:);         %bottom to top
     case 5
        IM = permute(IM, [2 1 3]);     %counterclockwise and upside down
     case 6
        IM = rot90(IM,3);              %undo 90 degree by rotating 270
     case 7
        IM = rot90(IM(end:-1:1,:,:));  %undo counterclockwise and left/right
     case 8
        IM = rot90(IM);                %undo 270 rotation by rotating 90
     otherwise
        warning(sprintf('unknown orientation %g ignored\n', orient));
   end
end
end