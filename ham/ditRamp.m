clc
clear all

% If I had more time I would have written you a shorter code

function r=morse(str)
	r=[];
	str=toupper(str);
	morsecode=" ETIANMSURWDKGOHVF L PJBXCYZQ  54 3   2  +    16=/   ( 7   8 90            ?_    \"  .    @   '  -        ;! )     ,    :";
	for s = str
		printf("'%c': ", s);

		idx=index(morsecode, s);
		if idx == 0
			printf(" unknown char\n\n");
			continue
		end
		bits=floor(log2(idx));
		if bits == 0
			r=[r, zeros(1, 3)]; %
		else
			for i = bits-1:-1:0
				v=bitand(idx, 2^i);
				if v > 0
					r=[r, 3];
					puts("_");
				else
					r=[r, 1];
					puts(".");
				end
			end
		end
		r=[r, 0];

		printf("\n");
	end
end
code=morse("CQ CQ CQ DE DL5IRO");

Fs=8000;

ditDuration=60e-3; % 20WpM = 60ms ; 12WpM = 100ms ; ms = 1200/WpM
F=700; % use 0Hz to hear/display the hull
% also you can hear the leakage from DC without the tone
% problem is hearing starts at about 20Hz and your ears are probalby not very linear in this range
B=0; % bandwidth of noise set to 0 to disable

rampOffset=1e-2; % initial step allowed to make
% a step of 1e-2 is equal to -40dB discontinuiti
% used by at least exp & hamming window
rampTime=5e-3;
% the ramp time is the total duration of the ramp
% the ramp is centered on the transient, and extends half in both direction

if rampTime > ditDuration
    printf("Invalid arguments: rampTime (%g) > ditDuration (%g)\n", rampTime, ditDuration)
end

tRamp=(0:rampTime*Fs)/(rampTime*Fs);

function r=rampCosiNuts(t, a0, a1=0, a2=0, a3=0, a4=0)
	r = a0 * cos(0*pi*t) - a1 * cos(1*pi*t) + a2 * cos(2*pi*t) - a3 * cos(3*pi*t) + a4 * cos(4*pi*t);
end

rampLinear=tRamp;
rampExp=exp((tRamp-1)*log(1/rampOffset));

% https://en.wikipedia.org/wiki/Window_function
rampRect=rampCosiNuts(tRamp, 1);
rampHann=rampCosiNuts(tRamp, 0.5, 0.5);
rampHamm=rampCosiNuts(tRamp, 0.5*(1+rampOffset), 0.5*(1-rampOffset));
rampBlack=rampCosiNuts(tRamp, 7938/18608, 9240/18608, 1430/18608);
rampNut =rampCosiNuts(tRamp, 0.355768, 0.487396, 0.144232, 0.012604);
rampBlackNut=rampCosiNuts(tRamp, 0.3635819, 0.4891775, 0.1365995, 0.0106411);
rampFlatTop=rampCosiNuts(tRamp, 0.21557895, 0.41663158, 0.277263158, 0.083578947, 0.006947368);

ramp=rampHann;

ditSamples=round(Fs*ditDuration);
Z=zeros(1,(ditSamples - length(ramp)));
R=ramp;
o=ones(1, ditSamples - length(ramp));
O=ones(1, ditSamples*3 - length(ramp));
r=flip(ramp);

DIT=[R, o, r, Z];
DAH=[R, O, r, Z];

A=[];

for s = code
	v=0;
	switch (s)
		case 0
			v=[Z, Z];
		case 1
			v=DIT;
		case 3
			v=DAH;
		otherwise
			printf("EXPLOSION");
			exit
	end
	A=[A, v];
end

A=[A, zeros(1, Fs/25)]; % Octave closes audio device too early, prevent audible click
t=(1:length(A))/Fs;
v=A.*cos(t*2*pi*F);

if B > 0
	pkg load signal

	f1=2*(F-B/2)/Fs;
	f2=2*(F+B/2)/Fs;

	f=fir2(round(50*Fs/F), [0, f1, f1, f2, f2, 1], [0,0,1,1,0,0], 1024*64, 1);
	freqz(f);
	noise=log(Fs)*rand(1,length(A)); % needs to be scaled with Fs, also make sure it's AWGN
	v=filter(f,1,v + noise);
end

plot(t,v)

player=audioplayer(v *0.1, Fs);
playblocking(player);


