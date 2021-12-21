function [uh,ph,info] = Stokes_mixedVEM(node,elem,pde,bdStruct)
%Stokes_mixedVEM solves Stokes problem using the mixed virtual element method
% in the lowest order k=2:  u = [u1,u2], f = [f1,f2]
%     
%     - nu*\Delta(u) - \nabla(p) = f   in Omega
%     div(u) = 0  in Omega
%     Dirichlet boundary condition   u = g on \Gamma
%
%  The mixed formulation is: Find (u,p) \in (V,Q) such that
%
%      a(u,v) + b(v,p) = (f,v),   v in V,
%      b(u,q) = 0, q in Q,
%
% where,
% - V = (H_0^1(Omega))^2,   Q = L_0^2(Omega)
% - u is approximated by the lowest order divergence-free  virtual element
%   (k = 2)
% - p by piecewise linear element (k = 2)
%      Q_{k-1}(K) = P_{k-1}(K).
%
%   References
%   L. Beirao da Veiga, C. Lovadina and G.Vacca, "Divergence free Virtual elements for
%   the Stokes problem on polygonal meshes", ESAIM Math. Model. Numer. Anal.,
%   Vol 51. No 2., pp. 509--535, 2017.
%
% Copyright (C)  Terence Yu. 

%% Get auxiliary data
% auxgeometry
aux = auxgeometry(node,elem);
node = aux.node; elem = aux.elem;
centroid = aux.centroid; diameter = aux.diameter; area = aux.area;
% auxstructure
auxT = auxstructure(node,elem);
elem2edge = auxT.elem2edge; edge = auxT.edge;
% number
N = size(node,1); NT = size(elem,1); NE = size(edge,1);
NNdofA = (N+NE)*2 + 2*NT;  NNdofB = 3*NT;  NNdof = NNdofA + NNdofB;
Nm = 6; Nmm = 2*Nm;

%% Compute projection matrices
D = cell(NT,1);  Bs = cell(NT,1);
G = cell(NT,1);  Gs = cell(NT,1); 
P0 = cell(NT,1); % P_{k-2}^0
Belem = cell(NT,1);
d = zeros(NT, 3); % for Lagrange multiplier
for iel = 1:NT    
    % ------- element information ----------
    index = elem{iel};     Nv = length(index);
    xK = centroid(iel,1); yK = centroid(iel,2); hK = diameter(iel);
    x = node(index,1); y = node(index,2);
    v1 = 1:Nv; v2 = [2:Nv,1]; % loop index for vertices or edges
    xe = (x(v1)+x(v2))/2;  ye = (y(v1)+y(v2))/2; % mid-edge points
    Ne = [y(v2)-y(v1), x(v1)-x(v2)]; % he*ne
    nodeT = [node(index,:);centroid(iel,:)];
    elemT = [(Nv+1)*ones(Nv,1),(1:Nv)',[2:Nv,1]'];
    
    % ------- scaled monomials --------
    m1 = @(x,y) 1+0*x;                  gradm1 = @(x,y) [0+0*x, 0+0*x];
    m2 = @(x,y) (x-xK)./hK;             gradm2 = @(x,y) [1/hK+0*x, 0+0*x];
    m3 = @(x,y) (y-yK)./hK;             gradm3 = @(x,y) [0+0*x, 1/hK+0*x];
    m4 = @(x,y) (x-xK).^2/hK^2;         gradm4 = @(x,y) [2*(x-xK)./hK^2, 0+0*x];
    m5 = @(x,y) (x-xK).*(y-yK)./hK^2;   gradm5 = @(x,y) [(y-yK)./hK^2, (x-xK)./hK^2];
    m6 = @(x,y) (y-yK).^2./hK^2;        gradm6 = @(x,y) [0+0*x, 2*(y-yK)./hK^2];
    
    m = @(x,y) [m1(x,y), m2(x,y), m3(x,y), m4(x,y), m5(x,y), m6(x,y)];
    Gradm = {gradm1, gradm2, gradm3, gradm4, gradm5, gradm6};    
    divmm = @(x,y) [0+0*x, 1/hK+0*x, 0+0*x, 2*(x-xK)./hK^2, (y-yK)./hK^2, 0+0*x, ...
        0+0*x, 0+0*x, 1/hK+0*x, 0+0*x, (x-xK)./hK^2, 2*(y-yK)./hK^2];
    
    % -------- transition matrix ----------
    NdofBd = 2*Nv; NdofA = 2*NdofBd+2;
    divmm2 = @(x,y) divmm(x,y).*repmat(m2(x,y),1,Nmm);
    divmm3 = @(x,y) divmm(x,y).*repmat(m3(x,y),1,Nmm);
    D1 = zeros(NdofA, Nmm);
    Dbd = [m(x,y); m(xe,ye)];
    D1(1:4*Nv, :) = blkdiag(Dbd, Dbd);
    D1(end-1,:) = integralTri(divmm2,4,nodeT,elemT);
    D1(end,:) = integralTri(divmm3,4,nodeT,elemT);
    D{iel} = D1;
    
    % --------- elliptic projection -----------
    % B
    % --- first term ---
    Lapm = [0, 0, 0, 2/hK^2, 0, 2/hK^2];
    B1 = zeros(Nmm, NdofA);
    B1(1:Nm, end-1) = pde.nu*hK*Lapm;
    B1(Nm+1:end, end) = pde.nu*hK*Lapm;
    % --- second term ---
    elem1 = [v1(:), v2(:), v1(:)+Nv]; % elem2dof for [ae, be, me]
    Gradmm = cell(2,Nmm);
    Gradmm(1,1:Nm) = Gradm; 
    Gradmm(2,Nm+1:end) = Gradm;
    for im = 1:Nm
        Gradmm{1,im+Nm} = @(x,y) [0+0*x, 0+0*x];
        Gradmm{2,im} = @(x,y) [0+0*x, 0+0*x];
    end
    qmm = cell(1,Nmm);  % q = nu*hK(c2*m2 + c3*m3)
    c2 = [Lapm, zeros(1,Nm)];
    c3 = [zeros(1,Nm), Lapm];    
    for im = 1:Nmm
        qmm{im} = @(x,y) pde.nu*hK*(c2(im)*m2(x,y) + c3(im)*m3(x,y));
    end
    for s = 1:2
        id = (1:NdofBd) + (s-1)*NdofBd;
        for im = 1:Nmm
            pm = @(x,y) pde.nu*Gradmm{s,im}(x,y);
            qa = @(x,y) qmm{im}(x,y);
            F1 = 1/6*(sum(pm(x(v1),y(v1)).*Ne, 2) - qa(x(v1),y(v1)).*Ne(:,s));
            F2 = 1/6*(sum(pm(x(v2),y(v2)).*Ne, 2) - qa(x(v2),y(v2)).*Ne(:,s));
            F3 = 4/6*(sum(pm(xe,ye).*Ne, 2) - qa(xe,ye).*Ne(:,s));            
            B1(im, id) = accumarray(elem1(:), [F1; F2; F3], [NdofBd, 1]);
        end
    end
    % constraint 
    P0K = zeros(2,NdofA);
    P0K(1, end-1) = -1; P0K(2, end) = -1;
    m23 = {m2, m3};
    for s = 1:2
        mc = m23{s};
        F1 = 1/6*(mc(x(v1),y(v1)).*Ne);  % [n1, n2]
        F2 = 1/6*(mc(x(v2),y(v2)).*Ne);
        F3 = 4/6*(mc(xe,ye).*Ne);
        F = [F1; F2; F3];
        P0K(s, 1:NdofBd) = accumarray(elem1(:), F(:,1), [NdofBd 1]);
        P0K(s, NdofBd+1:2*NdofBd) = accumarray(elem1(:), F(:,2), [NdofBd 1]);
    end
    P0K = 1/area(iel)*hK*P0K;
    % Bs, G, Gs
    B1s = B1;  B1s([1,7], :) = P0K;
    G{iel} = B1*D1;
    Bs{iel} = B1s;  Gs{iel} = B1s*D1;
    % P0
    P0{iel} = P0K';    
    
    % -------------- matrix for Qh ---------------
    BK = zeros(NdofA,3);
    BK(end-1, 2) = 1;  BK(end, 3) = 1;
    F = 1/6*[(1*Ne); (1*Ne); (4*Ne)]; % [n1, n2]
    BK(1:end-2,1) = accumarray([elem1(:);elem1(:)+NdofBd], F(:), [2*NdofBd 1]);
    Belem{iel} = reshape(BK',1,[]); % straighten as row vector for easy assembly 
    
    % ------------ Lagrange multiplier -------------
    md = @(x,y) [m1(x,y), m2(x,y), m3(x,y)];
    d(iel,:) = integralTri(md,3,nodeT,elemT);
end
d = d(:);

%% Get elementwise stiffness matrix and load vector
Aelem = cell(NT,1); belem = cell(NT,1);
Ph = cell(NT,1); % matrix for error evaluation
for iel = 1:NT
    % element information
    index = elem{iel};   Nv = length(index);   
    nodeT = [node(index,:);centroid(iel,:)];
    elemT = [(Nv+1)*ones(Nv,1),(1:Nv)',[2:Nv,1]'];
    % Projection
    Pis = Gs{iel}\Bs{iel};   Pi  = D{iel}*Pis;   I = eye(size(Pi));
    % Stiffness matrix A
    AK  = Pis'*G{iel}*Pis + (I-Pi)'*(I-Pi);
    Aelem{iel} = reshape(AK',1,[]); % straighten as row vector for easy assembly
    % Load vector f
    fxy = @(x,y) pde.f([x,y]); % f(p) = f([x,y]), f = [f1, f2]
    Pf = integralTri(fxy,3,nodeT,elemT); 
    P0K = P0{iel};
    fK = Pf(1)*P0K(:,1) + Pf(2)*P0K(:,2); 
    belem{iel} = fK'; % straighten as row vector for easy assembly
    % matrix for error evaluation
    Ph{iel} = Pis;
end

%% Assemble matrices A,B, and vector f,d
elemLen = cellfun('length',elem); vertNum = unique(elemLen);
nnzA = sum((4*elemLen+2).^2);  nnzB = sum((4*elemLen+2)*3); 
iiA = zeros(nnzA,1); jjA = zeros(nnzA,1); ssA = zeros(nnzA,1);
iiB = zeros(nnzB,1); jjB = zeros(nnzB,1); ssB = zeros(nnzB,1);
ffA = zeros(NNdofA,1); 
idA = 0; idB = 0; 
elem2dof = cell(NT,1);
for Nv = vertNum(:)' % only valid for row vector
    
    idNv = find(elemLen == Nv); % find polygons with Nv vertices
    NTv = length(idNv); % number of elements with Nv vertices
    
    % elem2dof 
    elemNv = cell2mat(elem(idNv));
    elem2edgeNv = cell2mat(elem2edge(idNv)); 
    elem2dofA = [elemNv, elem2edgeNv+N, ...
                 elemNv+N+NE, elem2edgeNv+2*N+NE, ...
                 idNv+2*N+2*NE, idNv+2*N+2*NE+NT];
    elem2dofB = [idNv, idNv+NT, idNv+2*NT];
    NdofA = 4*Nv+2; NdofB = 3;
    
    % assemble the matrix A    
    KA = cell2mat(Aelem(idNv));    
    iiA(idA+1:idA+NTv*NdofA^2) = reshape(repmat(elem2dofA, NdofA,1), [], 1);
    jjA(idA+1:idA+NTv*NdofA^2) = repmat(elem2dofA(:), NdofA, 1);
    ssA(idA+1:idA+NTv*NdofA^2) = KA(:);
    idA = idA + NTv*NdofA^2;
    
    % assemble the matrix B    
    KB = cell2mat(Belem(idNv));    
    iiB(idB+1:idB+NTv*NdofA*NdofB) = reshape(repmat(elem2dofA, NdofB,1), [], 1);
    jjB(idB+1:idB+NTv*NdofA*NdofB) = repmat(elem2dofB(:), NdofA, 1);
    ssB(idB+1:idB+NTv*NdofA*NdofB) = KB(:);
    idB = idB + NTv*NdofA*NdofB;

    % assemble the vector
    FA = cell2mat(belem(idNv));
    ffA = ffA + accumarray(elem2dofA(:),FA(:),[NNdofA 1]);
    
    % elementwise global indices
    elem2dof(idNv) = mat2cell(elem2dofA, ones(NTv,1), NdofA);
end
A = sparse(iiA,jjA,ssA,NNdofA,NNdofA);
B = sparse(iiB,jjB,ssB,NNdofA,NNdofB);

%% Get block linear system
kk = sparse(NNdof+1,NNdof+1);  ff = zeros(NNdof+1,1);
kk(1:NNdofA,1:NNdofA) = A;
kk(1:NNdofA, (1:NNdofB)+NNdofA) = B;
kk((1:NNdofB)+NNdofA, 1:NNdofA) = B';
kk((1:NNdofB)+NNdofA, end) = d;
kk(end, (1:NNdofB)+NNdofA) = d';
ff(1:NNdofA) = ffA;

%% Apply Dirichlet boundary conditions 
% bdDof, freeDof
bdNodeIdx = bdStruct.bdNodeIdx;
bdEdge = bdStruct.bdEdge;  bdEdgeIdx = bdStruct.bdEdgeIdx;
id = [bdNodeIdx; bdEdgeIdx+N; bdNodeIdx+N+NE; bdEdgeIdx+2*N+NE];
isBdDof = false(NNdof+1,1); isBdDof(id) = true;
bdDof = (isBdDof); freeDof = (~isBdDof);
% bdval
g_D = pde.g_D;
z1 = node(bdEdge(:,1),:); z2 = node(bdEdge(:,2),:); ze = (z1+z2)./2;
gv = g_D(node(bdNodeIdx,:));
ge = g_D(ze);
bdval = [gv(:,1); ge(:,1); gv(:,2); ge(:,2)]; 
% sol
sol = zeros(NNdof+1,1); 
sol(bdDof) = bdval;
ff = ff - kk*sol;

%% Set solver
sol(freeDof) = kk(freeDof,freeDof)\ff(freeDof);
uh = sol(1:NNdofA); % u = [u1(zv); u1(ze); u2(zv); u2(ze); divu*m2; divu*m3]
ph = sol(NNdofA+1:end-1);

%% Store information for computing errors
info.Ph = Ph; info.elem2dof = elem2dof; 
% info.kk = kk; %info.freeDof = freeDof;