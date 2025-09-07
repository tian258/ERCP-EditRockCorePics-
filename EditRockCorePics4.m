clc;clear;close all;

% ----------------------------------------------------------------------------
%   EditRockCorePics 使用说明:                                                                
% ----------------------------------------------------------------------------
% 
% 1）流程为: 
%   --> <Font.mat>文件与<EditRockCorePics4.m>文件放置在同一文件夹下
%   --> 编辑<输入参数.txt>,并放入岩芯照片文件夹 
%   --> 运行本脚本 
%   --> 选取<输入参数.txt>文件  
%   --> 选取岩芯照片 
%   --> 选取每张岩芯照片的四个角点
%   --> 等待自动生成带有标题的岩芯照片 
%   --> 在《岩芯照片》文件夹中查看结果
%
% 2）输入参数的格式: 
% 	在<输入参数.txt>文件中，
% 	第一行输入钻孔编号，
% 	第二行输入岩芯箱总数，
%	换行后每行输入每箱岩芯结束的孔深。
% 
% 例如: 假设有ZK07，共4箱，每箱结束的孔深为5、10、15、19.5m。则在<输入参数.txt>文件中输入: 
% 	ZK07
% 	4
% 	5
% 	10
% 	15
% 	19.5
%
% 3）岩芯照片要求: 
%  a.顺序: 岩芯照片在文件夹中必须按箱号从小到大排列。
%  b.岩芯照片必须摆正。
% 
% 4）选取岩芯箱四个角时的操作: 
%  a.点击岩芯箱四个角时，必须遵守顺序为左上、右上、左下、右下。
%  b.鼠标左键为选择; 
%    右键为取消上一个点; 
%    空格为确认四个点，进入下一张照片。
% ----------------------------------------------------------------------------
%   岩芯照片编辑( edit rock core pics, ERCP)脚本采用"活字印刷法"绘制岩芯照片标题，
% 使用双三次插值( Bicubic interpolation)透视变形( perspective transform)校正岩
% 芯箱图片。有改进意见可联系：tianxuezhou@163.com
% ----------------------------------------------------------------------------

global i;

% --------- 读取输入参数 ---------
load('Font.mat');
[InputName,InputAddress,c] = uigetfile('*.txt','选择<输入参数.txt>文件');
input = readcell(strcat(InputAddress,InputName));
Bname = char(input{1}) ; % 钻孔编号
Bnum = int16(input{2}) ; % 岩芯箱总数
kongshen = zeros(1,Bnum);

% ------ 编辑岩芯照片名字及抬头文字 -----
txt = num2cell(zeros(1,Bnum)); % 重命名的岩芯照片名字
for i = 1:Bnum
    kongshen(i) = input{i+2};
    if(i==1)
        if(kongshen(i)==round(kongshen(i))) % 后整
            txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：','0.0m～',num2str(kongshen(i)),'.0m'));
        else
            txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：','0.0m～',num2str(kongshen(i)),'m'));
        end
    else
        if(kongshen(i)==round(kongshen(i))) % 后整
            if(kongshen(i-1)==round(kongshen(i-1))) % 前整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'.0m～',num2str(kongshen(i)),'.0m'));
            else % 前不整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'m～',num2str(kongshen(i)),'.0m'));
            end
        else % 后不整
            if(kongshen(i-1)==round(kongshen(i-1))) % 前整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'.0m～',num2str(kongshen(i)),'m'));
            else % 前不整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'m～',num2str(kongshen(i)),'m'));
            end
        end
    end
end

% 创建文件夹titled，放置加好抬头的岩芯照片
foldername = strcat(InputAddress,'岩芯照片');
if ~exist(foldername,'dir')
    mkdir(foldername);
else
    % disp('岩芯照片文件夹 already exists');
end

% 选择岩芯照片
jpgnames = uigetfile(strcat(InputAddress,'*.*'),'选择岩芯照片', ...
    'MultiSelect','on');
k = length(jpgnames);
if (k~=Bnum)
    disp('岩芯箱数与照片总数不相等.');
    return
end

global RotTimes;

RotTimes = int16(zeros(1,k));
frame_m = int16(zeros(1,k));frame_n = int16(zeros(1,k));
corner_points = zeros(4,2,k);

% 获得屏幕尺寸
screenSize = get(0,'ScreenSize');
screenWidth = screenSize(3); screenHeight = screenSize(4);

% 设置窗口大小
windowWidth = screenWidth * 0.7;
windowHeight = screenHeight * 0.85;

% 计算窗口位置使其居中
windowX = (screenWidth - windowWidth) / 2;
windowY = (screenHeight - windowHeight) / 2;


% -----------------------------
% -------- 得到四角点位置 --------
% -----------------------------
global img;
for i = 1:k
    name = strcat(InputAddress,char(jpgnames{i}));
    img = imread(name); % 读岩芯照片


    % ---- 将有的照片倒转过来 ----
    % 尝试获取 EXIF 信息
    try
        info = imfinfo(name);
        % 检查是否存在 'Orientation' 字段
        if isfield(info, 'Orientation')
            orientation = info.Orientation;
        else
            orientation = 1; % 默认设为正常方向
        end
    catch
        orientation = 1; % 如果获取信息失败，也设为正常方向
    end
    
    % 根据 orientation 值旋转图像
    switch orientation
        case 1 % 正常
            corrected_img = img; % 无需旋转
        case 2 % 水平翻转 (较少见)
            corrected_img = flip(img, 2); % 沿垂直轴翻转
        case 3 % 旋转 180 度
            corrected_img = rot90(img, 2); % 旋转 180 度
        case 4 % 垂直翻转 (较少见)
            corrected_img = flip(img, 1); % 沿水平轴翻转
        case 5 % 先水平翻转再顺时针旋转270度 (较少见)
            corrected_img = rot90(flip(img, 2), 3);
        case 6 % 顺时针旋转 90 度 (iPhone竖屏拍摄常见)
            corrected_img = rot90(img, -1); % 逆时针旋转90度等于顺时针旋转270度
        case 7 % 先水平翻转再顺时针旋转90度 (较少见)
            corrected_img = rot90(flip(img, 2), -1);
        case 8 % 顺时针旋转 270 度
            corrected_img = rot90(img, 1); % 逆时针旋转90度
        otherwise
            corrected_img = img; % 默认情况
    end
    img = corrected_img;

    [m,n,r]=size(img); % m为照片y方向像素数（宽）；n为x方向像素数（长）

    global fig ax pointCount points pointMarkers lineObjs done;

    fig = figure('Name',strcat('选取 第',num2str(i),'箱 岩芯箱的四个角: '), ...
             'NumberTitle','off', 'Position', ...
             [windowX, windowY, windowWidth, windowHeight]);
    
    % ------- 选择四个角点 -------
    % 初始化变量
    points = zeros(4, 2); % 存储四个点的坐标
    pointCount = 0; % 已选点数
    pointMarkers = gobjects(4, 1); % 存储点图形对象
    lineObjs = gobjects(4,1); % 存储线图形对象
    done = false; % 完成选择标志
    ax = axes('Parent',fig,'Position',[0.05 0.05 0.9 0.9]);
    imshow(img,'Parent',ax);
    
    set(fig,'KeyPressFcn',@keyPressCallback);
    set(fig,'WindowButtonDownFcn',@mouseClickCallback);

    % 等待用户完成选择
    while ~done
        pause(0.1); % 短暂暂停以避免占用过多CPU
    end
    corner_points(:,:,i) = points;

     % --- 获得目标框框大小 ---
    leftdown = int16(points(1,:));rightdown = int16(points(2,:));
    leftup = int16(points(3,:));rightup = int16(points(4,:));
    frame_n(i) = round(mean( (rightup(1)-leftup(1)), (rightdown(1)-leftdown(1)) ));
    frame_m(i) = round(mean( (leftup(2)-leftdown(2)), (rightup(2)-rightdown(2)) ));

end



% ---------------------------------
% ------------ 主 循 环 ------------
% ---------------------------------

for i = 1:k
    disp(i);
    clear warped_img
    clear char

    % --- 把岩芯箱平直化 ---
    name = strcat(InputAddress,char(jpgnames{i}));
    img = imread(name); % 读岩芯照片
    % ---- 将有的照片倒转过来 ----
    % 尝试获取 EXIF 信息
    try
        info = imfinfo(name);
        % 检查是否存在 'Orientation' 字段
        if isfield(info, 'Orientation')
            orientation = info.Orientation;
        else
            orientation = 1; % 默认设为正常方向
        end
    catch
        orientation = 1; % 如果获取信息失败，也设为正常方向
    end
    
    % 根据 orientation 值旋转图像
    switch orientation
        case 1 % 正常
            corrected_img = img; % 无需旋转
        case 2 % 水平翻转 (较少见)
            corrected_img = flip(img, 2); % 沿垂直轴翻转
        case 3 % 旋转 180 度
            corrected_img = rot90(img, 2); % 旋转 180 度
        case 4 % 垂直翻转 (较少见)
            corrected_img = flip(img, 1); % 沿水平轴翻转
        case 5 % 先水平翻转再顺时针旋转270度 (较少见)
            corrected_img = rot90(flip(img, 2), 3);
        case 6 % 顺时针旋转 90 度 (iPhone竖屏拍摄常见)
            corrected_img = rot90(img, -1); % 逆时针旋转90度等于顺时针旋转270度
        case 7 % 先水平翻转再顺时针旋转90度 (较少见)
            corrected_img = rot90(flip(img, 2), -1);
        case 8 % 顺时针旋转 270 度
            corrected_img = rot90(img, 1); % 逆时针旋转90度
        otherwise
            corrected_img = img; % 默认情况
    end
    img = corrected_img;

    if (RotTimes(i)>0)
        while RotTimes(i)>4
            RotTimes(i) = RotTimes(i) - 4;
        end
        if (RotTimes(i)==1)
            img = rot90(img, -1);
        elseif (RotTimes(i)==2)
            img = rot90(img, 2);
        elseif (RotTimes(i)==3)
            img = rot90(img, 1);
        end
    end
    
    [m,n,r]=size(img); % m为照片y方向像素数（宽）；n为x方向像素数（长）

    frame_points = double([0,0; ...
                           frame_n(i),0; ...
                           0,frame_m(i); ...
                           frame_n(i),frame_m(i)]);
    tfom = fitgeotrans(corner_points(:,:,i),frame_points,'projective');

    output_view = imref2d;
    output_view.ImageSize = [fix(frame_m(i)),fix(frame_n(i))];
    output_view.XWorldLimits = [0,double(frame_n(i))];
    output_view.YWorldLimits = [0,double(frame_m(i))];

    warped_img(:,:,1) = imwarp(img(:,:,1),tfom,'outputview', ...
                    output_view,'Interp', 'bicubic');
    warped_img(:,:,2) = imwarp(img(:,:,2),tfom,'outputview', ...
                    output_view,'Interp', 'bicubic');
    warped_img(:,:,3) = imwarp(img(:,:,3),tfom,'outputview', ...
                    output_view,'Interp', 'bicubic');
    
    %%%% imshow(warped_img);

    % --- 做抬头照片 ---
    title = zeros(round(frame_n(i)*0.0625),frame_n(i),3,'uint8');
    title(:,:,1) = 253; % 黄色背景srgb(0,253,253)
    title(:,:,2) = 253;
    [m2,n2,l2] = size(title); % m2为抬头照片的y方向像素数（宽）
    m2 = int16(m2);n2 = int16(n2); l2 = int16(l2);

    titlename = char(txt{i});
    titlelen = length(titlename);
    FontHeight = m2-60;
    ydiff = int16((m2-FontHeight)*0.5);
    totalX = round(n*0.05);
    % 返回word matrix
    for j = 1:titlelen
        char = titlename(j);
        switch char
            case 'A'
                WM = word_A;
            case 'B'
                WM = word_B;
            case 'C'
                WM = word_C;
            case 'D'
                WM = word_D;
            case 'E'
                WM = word_E;
            case 'F'
                WM = word_F;
            case 'G'
                WM = word_G;
            case 'H'
                WM = word_H;
            case 'I'
                WM = word_I;
            case 'J'
                WM = word_J;
            case 'K'
                WM = word_K;
            case 'L'
                WM = word_L;
            case 'M'
                WM = word_M;
            case 'N'
                WM = word_N;
            case 'O'
                WM = word_O;
            case 'P'
                WM = word_P;
            case 'Q'
                WM = word_Q;
            case 'R'
                WM = word_R;
            case 'S'
                WM = word_S;
            case 'T'
                WM = word_T;
            case 'V'
                WM = word_V;
            case 'U'
                WM = word_U;
            case 'W'
                WM = word_W;
            case 'X'
                WM = word_X;
            case 'Y'
                WM = word_Y;
            case 'Z'
                WM = word_Z;
            case 'm'
                WM = word_smallm;
            case '.'
                WM = word_dot;
            case '～'
                WM = word_bolang;
            case '：'
                WM = word_maohao;
            case ' '
                WM = word_kongge;
            case '第'
                WM = word_di;
            case '箱'
                WM = word_xiang;
            case '孔'
                WM = word_kong;
            case '深'
                WM = word_shen;
            case '1'
                WM = word_one;
            case '2'
                WM = word_two;
            case '3'
                WM = word_three;
            case '4'
                WM = word_four;
            case '5'
                WM = word_five;
            case '6'
                WM = word_six;
            case '7'
                WM = word_seven;
            case '8'
                WM = word_eight;
            case '9'
                WM = word_nine;
            case '0'
                WM = word_zero;
            otherwise
                
        end
    
        [Wordy,Wordx,Wordz] = size(WM); % Wordy为y方向上的像素数
        FontWidth = int16( double(FontHeight) / Wordy * Wordx );
        WMa = imresize(WM, [FontHeight, FontWidth]);% word matrix adopted
        WMa(WMa>100) = 255; % 去除一些黑点
        
        title(ydiff+1:ydiff+FontHeight,totalX+1:totalX+FontWidth,:) = WMa;
        totalX = totalX + FontWidth;
    end

    % --- 将抬头照片与岩芯照片拼起来 ---

    answer = cat(1,title,warped_img); % 最终结果
    % imshow(answer);
    name = strcat(foldername,'\',titlename,'.jpg');
    imwrite(answer, name, Quality=95); % 保存图片

    disp(i);

end

% --------------------------------------
% ------------ 主 循 环 结 束 ------------
% --------------------------------------

close all;
disp('ALL DONE');
msgbox('已完成岩芯照片编辑.');



% 鼠标点击回调函数
function mouseClickCallback(~, ~)
    
    global fig ax pointCount points pointMarkers lineObjs;

    % 获取点击类型
    clickType = get(fig, 'SelectionType');
    
    % 左键点击 - 添加点
    if strcmp(clickType, 'normal')
        % 检查是否已经选择了4个点
        if pointCount >= 4
            % msgbox('已经选择了4个点，不能再添加更多点。', '提示', 'warn');
            return;
        end
        
        % 获取当前坐标
        currentPoint = get(ax, 'CurrentPoint');
        x = currentPoint(1,1);
        y = currentPoint(1,2);
        
        % 添加新点
        pointCount = pointCount + 1;
        points(pointCount, 1) = x;
        points(pointCount, 2) = y;
        
        % 绘制点
        hold(ax, 'on');
        pointMarkers(pointCount) = plot(ax, x, y, 'ro', 'MarkerSize', ...
                                    10, 'LineWidth', 2);
        hold(ax, 'off');
        
        % 如果已经有4个点，绘制连线
        if pointCount == 4
            % 清除之前的连线
            delete(lineObjs(ishandle(lineObjs)));
            
            % 绘制新的连线 (第一二、一三、二四、三四个点连接)
            hold(ax, 'on');
            
            % 线段1: 点1 → 点2
            lineObjs(1) = plot(ax, [points(1,1), points(2,1)], ...
                         [points(1,2), points(2,2)], 'g-', 'LineWidth', 1);
            
            % 线段2: 点1 → 点3
            lineObjs(2) = plot(ax, [points(1,1), points(3,1)], ...
                         [points(1,2), points(3,2)], 'g-', 'LineWidth', 1);
            
            % 线段3: 点2 → 点4
            lineObjs(3) = plot(ax, [points(2,1), points(4,1)], ...
                         [points(2,2), points(4,2)], 'g-', 'LineWidth', 1);
            
            % 线段4: 点3 → 点4
            lineObjs(4) = plot(ax, [points(3,1), points(4,1)], ...
                         [points(3,2), points(4,2)], 'g-', 'LineWidth', 1);
            
            hold(ax, 'off');
        end
        
        % 更新状态
        % set(infoText, 'String', sprintf('已选点: %d/4', pointCount));
        
     % 右键点击 - 取消最后选择的点
    elseif strcmp(clickType, 'alt')
        % 检查是否有可取消的点
        if pointCount > 0
            % 删除最后选择的点的图形对象
            if ishandle(pointMarkers(pointCount))
                delete(pointMarkers(pointCount));
            end
            
            % 清除该点的坐标
            points(pointCount, :) = [0, 0];
            
            % 减少点计数
            pointCount = pointCount - 1;
            
            % 清除所有连线（因为点的顺序可能改变）
            delete(lineObjs(ishandle(lineObjs)));
            lineObjs = gobjects(4, 1);
            
            % 如果还有足够的点，重新绘制连线
            if pointCount >= 2
                % 这里可以根据需要添加部分连线的绘制逻辑
                % 但由于连线方式依赖于四个点的特定组合，我们只在有四个点时绘制完整连线
            end
            
            % 更新状态
            % set(infoText, 'String', sprintf('已选点: %d/4', pointCount));
        else
            % msgbox('没有可取消的点。', '提示', 'help');
        end
    end
end

% 键盘按键回调函数
function keyPressCallback(~, event)
    global fig done img ax i RotTimes;
    % 空格键 - 结束选择
    if strcmp(event.Key, 'space')
        done = true;
        close(fig);
    end

    if strcmp(event.Key, 'r')
        img = rot90(img, -1); %
        imshow(img,'Parent',ax);
        RotTimes(i) = RotTimes(i) + 1;
    end
end


