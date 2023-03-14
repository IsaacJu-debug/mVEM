% extract vertices, edges, and faces of soccerball polyhedron
  % create a soccer ball mesh and display it
  [v, e, f] = createSoccerBall;
  drawMesh(v, f, 'faceColor', 'g', 'linewidth', 2);
  axis equal; view(3);

%% unit cubic
figure(1); clf;
[v, e, f] = createCube;
drawMesh(v, f);
view(3); axis('vis3d'); axis off;
title('Cube');