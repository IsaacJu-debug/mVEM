clc;clear;close all

load meshdata1.mat
rng(0);
opt_mesh = struct('facecolor','none');
opt_mark = struct('facecolor','r');

Iter = 8;
timetable = zeros(Iter, 2);
nElem = zeros(Iter, 1);

for i = 1 : Iter    
    % randomly give the marked elements
    marked = randi(length(elem), round([0.8*length(elem), 1]));
    
    % refine mesh and record time
    tic;
    [newnode1, newelem1] = PolyMeshRefine(node, elem, marked);
    timetable(i,1) = toc;
    tic;
    [newnode2, newelem2] = PolyMeshRefine1(node, elem, marked);
    timetable(i,2) = toc;
    
    % display time
    disp('Timetable');
    disp('PolyMeshRefine   PolyMeshRefine1');
    disp(timetable(1:i,:));
    
    % update node, elem
    node = newnode2;  elem = newelem2;
    nElem(i) = size(elem,1);    
    
    % display refined mesh given by PolyMeshRefine
    subplot(1,2,1);
    showmesh(newnode1, newelem1, opt_mesh);
    axis off;
    
    % display refined mesh given by PolyMeshRefine1
    subplot(1,2,2);
    showmesh(newnode2, newelem2, opt_mesh);
    axis off;
    
    drawnow;
end

figure;
loglog(nElem, timetable(:,1), '-x');
hold on;
loglog(nElem, timetable(:,2), '--o');
legend('PolyMeshRefine','PolyMeshRefine1');
xlabel('The number of resulting elements');
ylabel('Execution Time');