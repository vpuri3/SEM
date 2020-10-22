#!/usr/bin/env julia

# struct Name
#   field::OptionalType
#   ...
# end

#using SEM

using FastGaussQuadrature, LinearOperators
using Plots, LinearAlgebra
using SmoothLivePlot

using Krylov
linspace(zi::Number,ze::Number,n::Integer) = range(zi,stop=ze,length=n)

nx1 = 16; nxd = Int(ceil(1.5*nx1)); nxo = 10*nx1;
ny1 = 16; nyd = Int(ceil(1.5*ny1)); nyo = 10*ny1;

zr1,wr1 = gausslobatto(nx1); zrd,wrd = gausslobatto(nxd); zro=linspace(-1,1,nxo);
zs1,ws1 = gausslobatto(ny1); zsd,wsd = gausslobatto(nyd); zso=linspace(-1,1,nyo);

Jr1d = interpMat(zrd,zr1); Jr1o = interpMat(zro,zr1);
Js1d = interpMat(zsd,zs1); Js1o = interpMat(zso,zs1);

Dr1 = derivMat(zr1);
Ds1 = derivMat(zs1);

# nodal grid
r1,s1 = ndgrid(zr1,zs1);
rd,sd = ndgrid(zrd,zsd);

x1,y1 = r1,s1;          # solve on nodal grid for now.
xd,yd = rd,sd;

# case setup
#ifvel = false;    # evolve  vel field per NS eqn
#ifadv = false;    # advect  vel, sclr
#ifpr  = true ;    # project vel onto a div-free subspace
#ift   = true ;    # evolve sclr per advection diffusion eqn
#visc  = 1;

Jac1  = ones(nx1,ny1);  # unit jacobian
Jacd  = ones(nxd,nyd);

# diagonal mass matrices
B1  = (wr1 * ws1') .* Jac1;
Bd  = (wrd * wsd') .* Jacd;
Bi1 = 1 ./ B1;
Bid = 1 ./ Bd;

# all hom. dirichlet BC
m1=[0;ones(nx1-2);0]; m2=[0;ones(ny1-2);0];
M = m1 * m2';

kx=1
ky=1
ut = sin.(kx*pi*x1).*sin.(ky*pi*y1)
f  = ut .* ((kx^2+ky^2)*pi^2);

Br = Diagonal(wr1);
Bs = Diagonal(ws1);
Ar = Dr1'*Br*Dr1;
As = Ds1'*Bs*Ds1;

function laplOp(v)
    v = reshape(v,nx1,ny1);
    v = Ar*v*Bs' + Br*v*As';
    v = M .* v;
    v = reshape(v,nx1*ny1)
    return v;
end

function linsolve(A,B)
    return Krylov.cg(A,B);
end

Zygote.@adjoint function linsolve(A,B)
   Y,_ =  Krylov.cg(A,B)
   return Y, function(Ȳ)
     B̄,_ = Krylov.cg(A',Ȳ)
     println(size(-B̄ * Y'))
     return (-B̄ * Y', B̄)
   end
end

function solve(c)
    # f1(c)  = c.*ut .* ((kx^2+ky^2)*pi^2)
    f1(c)  = c[1].*ut .* ((c[2]^2+c[3]^2)*pi^2)
    op = LinearOperator(nx1*ny1,nx1*ny1,true,true
                       , v -> laplOp(v)
                       ,nothing
                       ,nothing);

    rhs = B1 .* f;
    rhsf(c) = reshape(B1 .* f1(c),nx1*ny1);
    u, stats = linsolve(op,rhsf(c));
    _,gp=pullback((c)->laplOp(u).-rhsf(c),c)
    #u ,stats = Krylov.cg(op,rhs);
    Lu = u.-reshape(ut,nx1*ny1);
    λ, stats = linsolve(op',Lu);
    Lp = gp(λ)
    u = reshape(u,nx1,ny1);
    return u,Lp;
end

function myplot(u,ut)
    sleep(0.001)
    fig1 = heatmap(u, clim = (minimum(ut),maximum(ut)))
    fig2 = heatmap(ut.-u, clim = (-1e-3,1e-3))
    plot(fig1, fig2, layout=2)
end

global c = [0.1,0.6,2]
u, Lp = solve(c)
# fig = @makeLivePlot myplot(u,ut)
sleep(1)
for i = 1:50
    #,c[1]*(c[2]^2+c[3]^2))
    u1, Lp1 = solve(c)
    println(sum(abs2,u1.-ut))
    global c = c + .002*Lp1[1]
    # modifyPlotObject!(fig,arg1=u1)
    sleep(0.1)
end
