
% https://en.wikipedia.org/wiki/Skin_effect

% Material mostly from
% https://en.wikipedia.org/wiki/Electrical_resistivity_and_conductivity#Resistivity_and_conductivity_of_various_materials
%
% Ωmm^2/m = µΩm = 1e-4 Ωcm
%p=0.016;n="Silver"
p=0.017;n="Copper"
%p=0.0265;n="Aluminium"
%p=0.03;n="Brass (5% Zn)"
%p=0.06;n="Brass (30% Zn)"
%p=0.07;n="Nickel"
%p=0.08;n="Nitinol"
%p=0.1;n="Iron"
%p=0.42;n="Titan"
%p=0.72;n="Stainless Steel" % (1.4301, V2A)

F=1e6 % Hz
ur=1; % Diamagnetic ≈1; µr
u=1.257e-6 * ur; % µ
l=1e3 % Length of wire [m]

D=1.6; % Diameter [mm]
AWG=Inf; % disable with Inf, only valid for ≥0
if AWG != Inf
	D=0.127*92^((36-AWG)/39);
end
D

function Rdc = computeRdc(D, p, l=1)
	Rdc=l.*p./(pi()./4*D.^2);
end

function Rac = computeRac(D, d, p, l=1)
	Rdc=computeRdc(D, p, l);
	% https://de.wikipedia.org/wiki/Skin-Effekt#Berechnung
	x=(D./(4*d));
	if x < 1
		Rac=Rdc .* (1 + (x.^4)/3);  % AC Resistance in Ω
	else
		Rac=Rdc .* x./(1-1./(4*x)); % AC Resistance in Ω
	end
end

d=sqrt(p/(pi()*F*u)) % skin depth in mm
Rdc=computeRdc(D, p, l) % DC Resistance in Ω
Rac=computeRac(D, d, Rdc) % AC Resistance in Ω

f=logspace(1, 8, 7*3+1);
figure(1)
hold off
loglog(f, sqrt(p./(pi()*f*u)))
grid on
hold on
loglog(f, D/2*ones(size(f)))
xlabel("F in [Hz]")
ylabel("Skin depth in [mm]")
legend("Skin depth", "D/2")
title(["Skin depth for Frequency of: " n])

D=0.2:0.01:1.6; % in mm
figure(2)
hold off
semilogy(D, computeRdc(D, p, l))
grid on
hold on
semilogy(D, computeRac(D, d, p, l))
xlabel("D in [mm]")
ylabel("R [Ω]")
legend("DC", ["AC @" num2str(F/1e6) " MHz"])
title(["Actual resistance for " n " with length " num2str(l) " m"])

