table1 =  zeros(7,7, 2);        
table2 = zeros(7, 7, 2);

all_pos = importdata("U24-4XAPO-EB-control-12wells-0525for10x.csv")
y = 6:-1:0;
x = -6:1:0;

for i=1:7
    for j = 1:7
        table1(i, j, :) = [1322*x(i)+all_pos(1,22)-18887 1322*y(j)+all_pos(2,22) ];
    end
end
table1_list = reshape(table1, 49,2);

for i=1:7
    for j = 1:7
        % set x position
        table2(i, j, 1) = table1(i, j, 1) - 35 + 18887;
        % set y position
        table2(i, j, 2) = table1(i, j, 2) + 18887; % all_pos(:, 145) -all_pos(:, 23)
    end
end
table2_list = reshape(table2, 49,2);

well = [ table1_list; table2_list ];
csvwrite("LLJ_24well_20x_20200706.csv", well');
