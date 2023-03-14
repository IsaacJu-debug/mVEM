function [elem3] = searchConn(elem)
% elem gives elem2node map
% elem3 gives face connectivity
% This routine only works with hexahedral element
localEle2Face = [3 4 1 2; 1 2 6 5; 2 3 7 6;1 4 8 5; 5 6 7 8; 4 3 7 8];
elemSize = size(elem, 1);
elem3 = cell(elemSize, 1);

faceNum = 6; 
faceNodeNum = 4;

for i = 1:elemSize
    % Loop through all elements
    localFace = cell(faceNum, 1);
    for j = 1:faceNum
        % each element has 6 faces
        f2n = [1 1 1 1];
        
        for k = 1:faceNodeNum
            % each face has 4 nodes
            f2n(k) = elem(i, localEle2Face(j, k));
        end
        
        localFace{j} = f2n;
    end
    elem3{i} = localFace;
end

