dz=2;
dt=20;
nt=200
t=(1:nt)*dt

tic;
mmc.setPosition(5000);
toc
temp=mmc.getPosition()
j1=0;
while abs(temp-5000)>1
    mmc.sleep(100);
    j1=j1+1;
    temp=mmc.getPosition();
    [j1*0.01 toc temp/1e3]
end

toc
z=5000+dz;

tic
%mmc.setRelativePosition(dz);
mmc.setPosition(z);
for i1=1:nt
    mmc.sleep(dt);
    temp=mmc.getPosition();
    z_t(i1,1)=toc;
    z_t(i1,2)=temp;
end
plot(z_t(:,1),z_t(:,2),'.-');
xlabel('time (second)')
ylabel('z (\mum)')

