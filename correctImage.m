function [correctedImage] = correctImage(imgStruct)
I = imgStruct(1).grayImg;

output = zeros(size(I));
[M, N] = size(output);
r = N/2;

for j = 1:N
    target = j - r;
    xprime = sin(target/r)*r;
    xprime = xprime + r;
    if(xprime > 0 && xprime < size(I,2))
        output(1:M,j) = I(1:M,round(xprime));
    end    
end
correctedImage = output;


