function [node, topol_all, elem3] = simpleRectMesh3d(nx,ny,nz,Lx,Ly,Lz, scale)

    % DESCRIPTION
    % Build a structured mesh with one fracture and define the boundaries

    nnx = nx+1;     % Node number in x direction
    nny = ny+1;     % Node number in y direction
    nnz = nz+1;     % Node number in z direction
    nn = nnx*nny*nnz; % Total node number
    ne = nx*ny*nz; % Number of hexa element
    %ne_tot = (2*nx+1)*ny*nz; % Total number of elements

    dx = Lx / nx; % grid size in x direction
    dy = Ly / ny; % grid size in y direction
    dz = Lz / nz; % grid size in z direction

    coord = zeros(nn,3); 
    kk = 0;
    z = 0;
    for i = 1 : nnz
        y = 0;
        for j = 1 : nny
            x = 0;
            for k = 1 : nnx
                kk = kk + 1;
                coord(kk,1) = x;
                coord(kk,2) = y;
                coord(kk,3) = z;
                x = x + dz;
            end
            y = y + dy;
        end
        z = z + dx;
    end

    %coordOrig = coord;
    scale1 = scale(1);
    fac = @(v) v + scale1*[2.0*dx*(rand(nn,1)-0.5),2.0*dy*(rand(nn,1)-0.5),2.0*dx*(rand(nn,1)-0.5)];
    coord = fac(coord);

    topol_all = zeros(ne,8);
    %id = zeros(ne_tot,1);
    nxy = nny*nnx;
    for i = 1 : nz
        for j = 1 : ny
            for k = 1 : nx
                kk = (i-1)*ny*nx + (j-1)*nx + k;
                %if (i == nx+1)
                %    id(kk) = 1;
                %end
                i1 = (i-1)*nxy + (j-1)*nnx + k;
                topol_all(kk,1) = i1;
                topol_all(kk,2) = i1+1;
                topol_all(kk,3) = i1+nnx+1;
                topol_all(kk,4) = i1+nnx;
                topol_all(kk,5) = i1+nxy;
                topol_all(kk,6) = i1+nxy+1;
                topol_all(kk,7) = i1+nxy+nnx+1;
                topol_all(kk,8) = i1+nxy+nnx;
            end
        end
    end
    node = coord;
    elem3 = searchConn(topol_all);
    
end
