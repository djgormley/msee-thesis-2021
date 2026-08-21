clear

N = 20;
M = 50;
z = zeros(N,M);

view(225,40)
xlabel('$t (s)$','interpreter','latex')
ylabel('$f \: (GHz)$','interpreter','latex')
zlabel('$P_{x}(t,f)$','interpreter','latex')
xlim([0 M]);ylim([0 N]);zlim([0 1])
set(gca,'TickLabelInterpreter','latex')
xticklabels(1:50)
yticklabels(1:21)
hold on
grid on
set(gcf,'visible','off');
%%
z(1,2:35) = ones(length(2:35),1)*0.1;
h = bar3(z,2); set(gcf,'visible','off');
recolor_bars(h, '#80B9DE');
z(1,1:35) = zeros(length(1:35),1);
%%
z(6,3:5) = ones(length(3:5),1)*0.2;
z(6,30:45) = ones(length(30:45),1)*0.2;
h = bar3(z,3); 
recolor_bars(h, '#ECA98C');
z(6,3:5) = zeros(length(3:5),1);
z(6,30:45) = zeros(length(30:45),1);
%%
z(10,1:50) = ones(length(1:50),1)*0.1;
h = bar3(z,1); set(gcf,'visible','off');
recolor_bars(h, '#F6D890');
z(10,1:50) = zeros(length(1:50),1);
%%
z(13,2:20) = ones(length(2:20),1)*0.05;
z(13,45:50) = ones(length(45:50),1)*0.05;
h = bar3(z,4); set(gcf,'visible','off')
recolor_bars(h, '#BF97C7');
z(13,2:20) = zeros(length(2:20),1);
z(13,45:50) = zeros(length(45:50),1);
%%
z(17,15:50) = ones(length(15:50),1)*0.2;
h = bar3(z,3); set(gcf,'visible','off')
recolor_bars(h, '#BBD698');
z(17,15:50) = zeros(length(15:50),1);
%%
z(1,50) = ones(length(50),1)/100;
h = bar3(z,1000); 
z(1,50) = zeros(length(50),1);
recolor_bars(h, 'w');

print('../plots/spectrum_sensing', '-dpng')

%% Local Functions
function recolor_bars(h, hex_color)
    cm = get(gcf,'colormap');
    cnt = 0;
    for jj = 1:length(h)
        xd = get(h(jj),'xdata');
        yd = get(h(jj),'ydata');
        zd = get(h(jj),'zdata');
        delete(h(jj))    
        idx = [0;find(all(isnan(xd),2))];
        if jj == 1
            S = zeros(length(h)*(length(idx)-1),1);
            dv = floor(size(cm,1)/length(S));
        end
        for ii = 1:length(idx)-1
            cnt = cnt + 1;
            S(cnt) = surface(xd(idx(ii)+1:idx(ii+1)-1,:),...
                             yd(idx(ii)+1:idx(ii+1)-1,:),...
                             zd(idx(ii)+1:idx(ii+1)-1,:),...
                             'facecolor',cm((cnt-1)*dv+1,:));
        end
    end
    set(S(:,1),'facecolor', hex_color)
end