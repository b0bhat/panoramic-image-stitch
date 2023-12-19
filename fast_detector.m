function [ret] = fast_detector(image, threshold)
I=image;
corners=[];
num=9;
ring_x=zeros(16,1);
ring_y=zeros(16,1);

% consider ring
for x=4:size(I,2)-3
    for y=4:size(I,1)-3
        %x coordinates
        [ring_x(1),ring_x(9)]=deal(x);
        [ring_x(2),ring_x(8)]=deal(x+1);
        [ring_x(3),ring_x(7)]=deal(x+2);
        [ring_x(4),ring_x(5),ring_x(6)]=deal(x+3);
        [ring_x(10),ring_x(16)]=deal(x-1);
        [ring_x(11),ring_x(15)]=deal(x-2);
        [ring_x(12),ring_x(13),ring_x(14)]=deal(x-3);
        %y coordinates
        [ring_y(5),ring_y(13)]=deal(y);
        [ring_y(4),ring_y(14)]=deal(y-1);
        [ring_y(3),ring_y(15)]=deal(y-2);
        [ring_y(1),ring_y(2),ring_y(16)]=deal(y-3);
        [ring_y(6),ring_y(12)]=deal(y+1);
        [ring_y(7),ring_y(11)]=deal(y+2);
        [ring_y(8),ring_y(9),ring_y(10)]=deal(y+3);

        pvalmin = I(y,x)-I(y,x)*threshold;
        pvalplus = I(y,x)+I(y,x)*threshold;

        if num>=12
            if I(y-3,x)<=pvalmin && I(y+3,x)<=pvalmin && I(y,x+3)>=pvalmin && I(y,x-3)>=pvalmin, continue;
            elseif I(y-3,x)>=pvalplus && I(y+3,x)>=pvalplus && I(y,x+3)<=pvalplus && I(y,x-3)<=pvalplus, continue;
            elseif I(y,x+3)<=pvalmin && I(y,x-3)<=pvalmin && I(y-3,x)>=pvalmin && I(y+3,x)>=pvalmin, continue;
            elseif I(y,x+3)>=pvalplus && I(y,x-3)>=pvalplus && I(y-3,x)<=pvalplus && I(y+3,x)<=pvalplus, continue;
            end
        end
        % starting pixel of the circle
        for j=1:16
            if I(ring_y(j),ring_x(j))<=pvalmin || I(ring_y(j),ring_x(j))>=pvalplus
                shift=j+1;
                count = 1;
                if shift>16, shift=shift-16;
                end
                while count<num
                    if I(ring_y(shift),ring_x(shift))<=pvalmin || I(ring_y(shift),ring_x(shift))>=pvalplus
                        count=count+1;
                        shift=shift+1;
                        if shift>16, shift=shift-16;
                        end
                    else
                        break;
                    end
                end
                if count==num
                    corners=[corners; x y];
                    break;
                end
            end
        end
    end
end
ret = cornerPoints(corners);
%{
figure;
imshow(I);
hold on;
for i=1:length(corners)
    plot(corners,'yo');
end
hold off;
%}
end
