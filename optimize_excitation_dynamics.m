% mRNA imaging 120 time points, spinning disk 2021-01-19
tao1=6.30
tao2=450;
a1=0.16;
a2=0.84;
X1=ones(1,120);
%X2=0.80:0.002:1.1;
% X2=0.8+0.15*log10(1:120);
% %X2=0.8+0.25*exp((-119:0)/50);
X2=0.94+0.18/120^2*(1:120).^2;

for i1=1:120
    I1(i1)=X1(i1)*(a1*exp(-sum(X1(1:i1))/tao1)+a2*exp(-sum(X1(1:i1))/tao2));
    I2(i1)=X2(i1)*(a1*exp(-sum(X1(1:i1))/tao1)+a2*exp(-sum(X1(1:i1))/tao2));
end
figure(4)
plot(I1,'*-');hold on
plot(I2,'p-');hold off
laser_dynamics=ceil(X2*100*100/112)/10;
Exposure=280;
save('dynamic_excitation.mat','laser_dynamics','Exposure');
