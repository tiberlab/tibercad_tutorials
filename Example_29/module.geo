// PEARL Project
// CHOSE perovskite module layout
//
// all measures in mm

// active cell witdh
W = 40;

// subcell stripe length
L = 5;

// number of subcells
N = 5;

// P1 + safety
P1 = 0.016 + 0.03;
// P2 width
P2 = 0.2;
// P3 + safety
P3 = 0.1 + 0.025;

// contact access length
Lc = 4 - 0.055/2;

// cell layout:
// cathode - P2P3 - cell - P1P2P3 - ... - P1P2 - anode

// characteristic length
d = 0.2;

// number of elements along width
Nw = 25;

x = 0;
Point(1) = {x, 0, 0, d};
x = x + Lc;
Point(2) = {x, 0, 0, d}; 
Line(1) = {1, 2};
lastp = 2;
t[] = Extrude {0, W, 0} { Line {1}; Layers {Nw}; Recombine; }; 
Physical Line("cathode") = {-t[3]};
access[] = {t[1]};
side[] = {-1, t[0], -t[3]};
p1[] = {};
p2[] = {};
p3[] = {};
active[] = {};


// first P2 is doubled
x = x + P2;

For i In {1:N}
  x = x + P2;
  p = newp; Point(p) = {x, 0, 0, d};
  l = newl; Line(l) = {lastp, p};
  t[] = Extrude {0, W, 0} { Line {l}; Layers {Nw}; Recombine; };
  p2 = {p2[], t[1]};
  side[] = {side[], -l, t[0]};
  lastp = p;

  x = x + P3;
  p = newp; Point(p) = {x, 0, 0, d};
  l = newl; Line(l) = {lastp, p};
  t[] = Extrude {0, W, 0} { Line {l}; Layers {Nw}; Recombine; };
  side[] = {side[], -l, t[0]};
  p3 = {p3[], t[1]};
  lastp = p;

  x = x + L;
  p = newp; Point(p) = {x, 0, 0, d};
  l = newl; Line(l) = {lastp, p};
  t[] = Extrude {0, W, 0} { Line {l}; Layers {Nw}; Recombine; };
  active = {active[], t[1]};
  side[] = {side[], -l, t[0]};
  lastp = p;

  x = x + P1;
  p = newp; Point(p) = {x, 0, 0, d};
  l = newl; Line(l) = {lastp, p};
  t[] = Extrude {0, W, 0} { Line {l}; Layers {Nw}; Recombine; };
  side[] = {side[], -l, t[0]};
  p1 = {p1[], t[1]};
  lastp = p;
EndFor

// last P2 is doubled
x = x + 2*P2;
p = newp; Point(p) = {x, 0, 0, d};
l = newl; Line(l) = {lastp, p};
t[] = Extrude {0, W, 0} { Line {l}; Layers {Nw}; Recombine; };
side[] = {side[], -l, t[0]};
p2 = {p2[], t[1]};
lastp = p;

x = x + Lc;
p = newp; Point(p) = {x, 0, 0, d}; 
l = newl; Line(l) = {lastp, p};
t[] = Extrude {0, W, 0} { Line {l}; Layers {Nw}; Recombine; };
Physical Line("anode") = {t[2]};
side[] = {side[], -l, t[0], -t[2]};
access = {access[], t[1]};

Le = 5;
p = newp; Point(p) = {-Le, -Le, 0, 0.5};
p = newp; Point(p) = {x + Le, -Le, 0, 0.5};
p = newp; Point(p) = {x + Le, W+Le, 0, 0.5};
p = newp; Point(p) = {-Le, W+Le, 0, 0.5};
l = newl; Line(l) = {p-3, p-2};
l = newl; Line(l) = {p-2, p-1};
l = newl; Line(l) = {p-1, p};
l = newl; Line(l) = {p, p-3};
Physical Line("surface") = {l-3, l-2, l-1, l};

Curve Loop(1) = {116, 117, 118, 119, side[]};
Plane Surface(116) = {1};
Physical Surface("encapsulation") = {116};


Physical Surface("active") = {active[], access[]};
//Physical Surface("access") = {access[]};
Physical Surface("P1") = {p1[]};
Physical Surface("P2") = {p2[]};
Physical Surface("P3") = {p3[]};

