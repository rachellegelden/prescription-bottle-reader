
%send a stuct of images in rgb form with the table name rgbImg;
%will find the largest object that center of the image in with in the bounding box;
%returns a set im rgb images with the  convexImage (mask of image location)
%all images in the set are on the same axis and have the same size;
function [imgSet, maxX, maxY] = normalizeImageSet(rgbImgStuct)


	
	maxX = [];
	maxY = [];
	
	for i = 1:length(rgbImgStuct)
		%finds the largest object in the center of the screen.
		rgbImg = findItemAndCorrectObj(rgbImgStuct(i).rgbImg, rgbImgStuct(i));
		imgSet(i).rgbImg = rgbImg;
        imgSet(i).title = rgbImgStuct.title;
		
		%find the smallest size image;
		[tempImgX, tempImgY, ~] = size(rgbImg);
		maxX = [maxX, tempImgX];
		maxY = [maxY, tempImgY];
	end
	
	maxX = mean(maxX, 'all');
	maxY = mean(maxY, 'all');
	
	%normalizing images to be the same size
	for i = 1:length(imgSet)
		%rotates the image;
        rgbImg = imresize(imgSet(i).rgbImg,[maxX, maxY],'lanczos3');
        imgSet(i).rgbImg = rgbImg;
		
		%finds the new convex hull
        grayImg = rgb2gray(imgSet(i).rgbImg);
        imgSet(i).grayImg = grayImg;
    end
    
end

%find the center largest object
function [item] = findItemAndCorrectObj(img, imgStuct)
ExtraThrestholdingY = 60;
grayImg = rgb2gray(img);

smoothImg = imgaussfilt(grayImg, 10);

averageIntensity = mean(smoothImg,'all');
mask = smoothImg > averageIntensity+ExtraThrestholdingY;


%rotates image to be vertical according to the orientation
fXL = regionprops(mask, 'Orientation','BoundingBox','Area');
stuct = stuctFindItem(fXL, imgStuct);

%roates image based on Orientation
rotate = 0;
orientation = stuct(1).Orientation;
if orientation < 0
    rotate = (orientation + 90) * -1;
elseif orientation > 0
    rotate = 90 - orientation;
end
imgStuct.rgbImg = imrotate(imgStuct.rgbImg, rotate, 'bicubic', 'crop');


%after rotates we need to know where the object is. 
%finds the location of the new objects bounding box
grayImg = rgb2gray(imgStuct.rgbImg);
smoothImg = imgaussfilt(grayImg, 10);
mask = smoothImg > averageIntensity+ExtraThrestholdingY;


newfXL = regionprops(mask,'Orientation','BoundingBox','Area');
newStuct = stuctFindItem(newfXL, imgStuct);

y0 = newStuct(1).BoundingBox(1);
x0 = newStuct(1).BoundingBox(2);
y1 = newStuct(1).BoundingBox(3) + y0;
x1 = newStuct(1).BoundingBox(4) + x0;

%returns only shot of the object in rgb
item = imgStuct.rgbImg(x0:x1,y0:y1,:);
end


%finds largest object in center if image.
%image center must be within the bounding box of the object;
function [struct] = stuctFindItem(entry, imgStuct)
maxArea = 0;
index = 0;
tempImg = imgStuct.rgbImg;
[m, n, ~] = size(tempImg);

for i =1:length(entry)
    %imshow(tempImg), title(strcat(imgStuct.title, 'object: ', int2str(i)));
    
    y0 = entry(i).BoundingBox(1);
    x0 = entry(i).BoundingBox(2);
    y1 = entry(i).BoundingBox(3) + y0;
    x1 = entry(i).BoundingBox(4) + x0;
    
    centerX = m/2;
    centerY = n/2;
    
    %line([centerX-25 centerX+25], [centerY centerY], 'Color', 'r','LineWidth',1);
    %line([centerX centerX], [centerY-25 centerY+25], 'Color', 'r','LineWidth',1);
    %rectangle('Position', entry(i).BoundingBox, 'EdgeColor','r','LineWidth',1);
    
    %find object with bounding box that contains the center of the screen.
    if entry(i).Area > maxArea && centerX > x0 && centerX < x1 && centerY > y0 && centerY < y1
        maxArea = entry(i).Area;
        index = i;
    end
end

%if no bounding boxes contaning the center of image, use largest.
if index == 0
    for i =1:length(entry)
        if entry(i).Area > maxArea
            maxArea = entry(i).Area;
            index = i;
        end
    end
end
    struct = entry(index);
end