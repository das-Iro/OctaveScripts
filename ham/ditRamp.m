clc
clear all

# If I had more time I would have written you a shorter code

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
code=morse("CQ DE DL5IRO");
code=morse("CQ");

Fs=8000;

ditDuration=60e-3; % 20WpM = 60ms ; 12WpM = 100ms ; ms = 1200/WpM
F=550; % use 0Hz to hear/display the hull
# also you can hear the leakage from DC without the tone
# problem is hearing starts at about 20Hz and your ears are probalby not very linear in this range
B=50; % bandwidth of filter set to 0 to disable

# Add noise if snr < 100 in dB
# this is representativ to what FT8 claims as SNR reference is a 2.5kHz wide channel
# However a 100Hz channel is skewed by 14dB
snr=-10;
printf("SNR %.1f dB for B=%.0f Hz\n", snr-log10(B/2500)*10, B); # print true SNR for B

rampOffset=1e-2; % initial step allowed to make
# a step of 1e-2 is equal to -40dB discontinuiti
# used by at least exp & hamming window
rampTime=5e-3;
# the ramp time is the total duration of the ramp
# the ramp is centered on the transient, and extends half in both direction

if rampTime > ditDuration
    printf("Invalid arguments: rampTime (%g) > ditDuration (%g)\n", rampTime, ditDuration)
end

tRamp=(0:rampTime*Fs)/(rampTime*Fs);

function r=rampCosiNuts(t, a0, a1=0, a2=0, a3=0, a4=0)
	r = a0 * cos(0*pi*t) - a1 * cos(1*pi*t) + a2 * cos(2*pi*t) - a3 * cos(3*pi*t) + a4 * cos(4*pi*t);
end

rampLinear=tRamp;
rampExp=exp((tRamp-1)*log(1/rampOffset));

# https://en.wikipedia.org/wiki/Window_function
rampRect=rampCosiNuts(tRamp, 1);
rampHann=rampCosiNuts(tRamp, 0.5, 0.5);
rampHamm=rampCosiNuts(tRamp, 0.5*(1+rampOffset), 0.5*(1-rampOffset));
rampBlack=rampCosiNuts(tRamp, 7938/18608, 9240/18608, 1430/18608);
rampNut =rampCosiNuts(tRamp, 0.355768, 0.487396, 0.144232, 0.012604);
rampBlackNut=rampCosiNuts(tRamp, 0.3635819, 0.4891775, 0.1365995, 0.0106411);
rampFlatTop=rampCosiNuts(tRamp, 0.21557895, 0.41663158, 0.277263158, 0.083578947, 0.006947368);

# select the "window function" for ramp
ramp=rampNut;

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

A=[A, zeros(1, Fs)]; # Octave closes audio device too early, prevent audible click
t=(1:length(A))/Fs;
v=A.*sqrt(2).*cos(t*2*pi*F);

if snr < 100
	pkg load communications
	snr+=log10(2500/Fs)*10; # Hamradio "standard" is a 2.5kHz channel
	v=awgn(v, snr);
end

if B > 0
	pkg load signal

	f1=2*(F-B/2)/Fs;
	f2=2*(F+B/2)/Fs;
	N=round(Fs * ditDuration * 10);
	if f1 > 0
		f=fir2(N, [0, f1, f1, f2, f2, 1], [0,0,1,1,0,0]);
	else
		f=fir2(N, [0, 2*B/Fs, 2*B/Fs, 1], [1,1,0,0]);
	end
	[H W]=freqz(f);

	subplot(2, 1, 1);
	plot(W, 20*log10(abs(H)));
	grid("on");
	axis([W(1) W(end) -100 1]);
	xlabel('Normalized Frequency [\times\pi rad/sample]');
	ylabel("Magnitude [dB]");
	subplot(2, 1, 2);

	v=filter(f,1,v);
end

plot(t,v)
xlabel('Time');
ylabel("Amplitude");

player=audioplayer(v *0.05, Fs);
playblocking(player);


