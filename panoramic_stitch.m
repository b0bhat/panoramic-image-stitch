function [] = panoramic_stitch()

%images = ["im1.jpg" "im2.jpg"];
images = ["1.jpeg" "2.jpeg"];
numImages = length(images);
imageResized = cell(1, numImages);

% Resize images
disp("RESIZE")
for i = 1:numImages
    I = imread(images(i));
    [x y z] = size(I);
    area = x * y;
    limit = 1000000;
    if area > limit
        scale = sqrt(limit / area);
        yN = round(y * scale);
        xN = round(x * scale);
        imageResized{i} = imresize(I,[xN,yN]);
    end
end

% FAST and Harris Detection
disp("FAST")
sobel = [-1 0 1; -2 0 2; -1 0 1];
gaus = fspecial('gaussian', 7, 1);
dog = conv2(gaus, sobel);
function [features, pointDsc] = calculateFeatures(image, fast_threshold, harris_threshold, method)
    fast = fast_detector(image, fast_threshold);
    fast_h = fast.Location;
    fast_h = uniquetol(fast_h, 0.0001, 'ByRows', true);
    fast_x = fast_h(:, 2);
    fast_y = fast_h(:, 1);
    
    points = zeros(size(image));
    for l = 1:length(fast_x)
        points(fast_x(l), fast_y(l)) = 255;
    end
    
    ix = imfilter(image, dog);
    iy = imfilter(image, dog');
    ix2 = imfilter(ix .* ix, gaus);
    iy2 = imfilter(iy .* iy, gaus);
    ixiy = imfilter(ix .* iy, gaus);
    harris = ix2 .* iy2 - ixiy .* ixiy - 0.05 * (ix2 + iy2) .^ 2;
    points(~(harris > harris_threshold)) = 0;
    [y, x] = find(points == 255);
    points = cornerPoints([x, y]);
    [features, pointDsc] = extractFeatures(image, points, 'Method', method);
end

% Processing images
disp("PROCESSING")
imageSize = zeros(numImages,2);
features = cell(1, numImages);
pointers = cell(1, numImages);
for i = 1:numImages
    disp(i)
    image = im2gray(imageResized{i});
    imageSize(i,:) = size(image);
%    image = imresize(image, 0.8);
    [features{i}, pointers{i}] = calculateFeatures(image, 0.3, 20, 'FREAK');
end
% indexPairs = zeros(numImages, numImages);
% for i = 1:numImages
%     for j = 1:numImages
%         if j == i
%             break
%         end
%         indexPairs(i,j) = numel(matchFeatures(features{i}, features{j}, 'Unique', true));
%     end
% end
% disp(indexPairs);
% G = graph(tril(indexPairs, -1));
% optimal_path = shortestpath(G, 1, numImages, 'Method', 'positive');
% disp(optimal_path);
% return

%RANSAC and image stitching
disp("RANSAC")
tforms(numImages) = projtform2d;
for i=2:numImages
    disp(i)
    indexPairs = matchFeatures(features{i}, features{i-1}, 'Unique', true);
    matchedPoints = pointers{i}(indexPairs(:,1), :);
    matchedPointsPrev = pointers{i-1}(indexPairs(:,2), :);        
    tforms(i) = estgeotform2d(matchedPoints, matchedPointsPrev,...
        'projective', 'Confidence', 99.9, 'MaxNumTrials', 2000);
    tforms(i).A = tforms(i-1).A * tforms(i).A; 
end
disp("TRANSFORMS")
for i = 1:numel(tforms)           
    [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 imageSize(i,2)], [1 imageSize(i,1)]);    
end
avgXLim = mean(xlim, 2);
[~,idx] = sort(avgXLim);
centerIdx = floor((numel(tforms)+1)/2);
centerImageIdx = idx(centerIdx);
Tinv = invert(tforms(centerImageIdx));
for i = 1:numel(tforms)    
    tforms(i).A = Tinv.A * tforms(i).A;
end

for i = 1:numel(tforms)           
    [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 imageSize(i,2)], [1 imageSize(i,1)]);
end
maxImageSize = max(imageSize);

disp("STITCH")
% Find the minimum and maximum output limits. 
xMin = min([1; xlim(:)]);
xMax = max([maxImageSize(2); xlim(:)]);

yMin = min([1; ylim(:)]);
yMax = max([maxImageSize(1); ylim(:)]);

% Width and height of panorama.
width  = round(xMax - xMin);
height = round(yMax - yMin);

% Initialize the "empty" panorama.
panorama = zeros([height width 3], 'like', imageResized{1});
% Put in some form of termination if feature match is too low which
% results in a giant panorama based on weird xlim/ylims

blender = vision.AlphaBlender('Operation', 'Binary mask', ...
    'MaskSource', 'Input port');  

% Create a 2-D spatial reference object defining the size of the panorama.
xLimits = [xMin xMax];
yLimits = [yMin yMax];
panoramaView = imref2d([height width], xLimits, yLimits);
% Create the panorama.
disp("PANORAMA")
for i = 1:numImages
    I = imageResized{i};
    warpedImage = imwarp(I, tforms(i), 'OutputView', panoramaView);
    mask = imwarp(true(size(I,1),size(I,2)), tforms(i), 'OutputView', panoramaView);
    panorama = step(blender, panorama, warpedImage, mask);
end
figure
imshow(panorama)
imname = sprintf('panorama.png');
imwrite(panorama,imname);

end