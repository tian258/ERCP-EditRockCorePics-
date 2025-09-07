clc;clear;close all;

% ----------------------------------------------------------------------------
%   Instructions for using EditRockCorePics 4.0:                                                                
% ----------------------------------------------------------------------------
% 
% (1) Work flow: 
%   --> The <Font.mat> file and the <EditRockCorePics4.m> file should be 
%       placed in the same folder.
%   --> Edit <InputPara.txt> and place it in the same folder with initial
%       core photos.
%   --> Run this script.
%   --> Select the <InputPara.txt> file.
%   --> Select rock core photos.
%   --> Select 4 corner points of the box for each photo.
%   --> Waiting for automatic generations of images with titles .
%   --> Check the photos in the folder "titled".
%
% (1) Format of input parameters：
% 	In the file <InputPara.txt>,
% 	The first line is the drill hole name.
% 	The second line is the total number of rock core boxes.
% 	After the line breaks, each line represents the hole-depth at the end of
% 	each box.
% 
% For example：Assuming there are 4 boxes of drill hole ZK07, with 
% 	hole-depths of 5m, 10m, 15m, and 19.5m at the end of boxes. 
% 	Then in the <InputPara.txt> file, write:
% 	ZK07
% 	4
% 	5
% 	10
% 	15
% 	19.5
%
% (3) Order of rock core photos：
%  a.Rock core photos must be arranged in ascending order in the folder.
%  b.Put the photos right.
% 
% (4) Operations when selecting 4 corner points of the boxes：
%  a. When clicking the four corners of the boxes, must follow the 
%  	 order: top left, top right, bottom left, and bottom right.
%  b. Left mouse button click for selection;  
%  	 Right-click for cancelling the previous one point;  
%  	 Press the spacebar to confirm the 4 points and go on to the next photo.
% ----------------------------------------------------------------------------
%    The script for editing rock core photos( ERCP) use the "moveable 
% type printing method" to draw the titles of rock core photos, and 
% use bicubic-interpolation-image-perspective-transform to correct the 
% frame of the rock core boxes. Any suggestions, please contact: 
% tianxuezhou@163.com
% ----------------------------------------------------------------------------

global i kongshen;

% --------- Read input parameters ---------
load('Font.mat');
[InputName,InputAddress,c] = uigetfile('*.txt','Select file <InutPara.txt>');
input = readcell(strcat(InputAddress,InputName));
Bname = char(input{1}) ; % Drill hole name 
Bnum = int16(input{2}) ; % Total number of boxes
kongshen = zeros(1,Bnum);

% ------ Edit titles -----
txt = num2cell(zeros(1,Bnum)); % Rename the photos
txt = RenamePics(Bnum, input, Bname);

% Create the folder "titled" and place the final photos there
foldername = strcat(InputAddress,'titled');
if ~exist(foldername,'dir')
    mkdir(foldername);
else
    % disp('titled folder already exists');
end

% Select rock core photos
jpgnames = uigetfile(strcat(InputAddress,'*.*'),'Select rock core photos', ...
    'MultiSelect','on');
k = length(jpgnames);
if (k~=Bnum)
    disp('The total number of boxes DOES NOT match the number of photos.');
    return
end

global RotTimes;

RotTimes = int16(zeros(1,k));
frame_m = int16(zeros(1,k));frame_n = int16(zeros(1,k));
corner_points = zeros(4,2,k);

% Obtain screen size
screenSize = get(0,'ScreenSize');
screenWidth = screenSize(3); screenHeight = screenSize(4);

% Set window size
windowWidth = screenWidth * 0.7;
windowHeight = screenHeight * 0.85;

% Calculate the window position and make it centered
windowX = (screenWidth - windowWidth) / 2;
windowY = (screenHeight - windowHeight) / 2;


% ----------------------------------------
% -------- Get four corner points --------
% ----------------------------------------
global img;
for i = 1:k
    name = strcat(InputAddress,char(jpgnames{i}));
    img = imread(name); % read photo


    % ---- Flip some photos ----
    % Try to get parameter EXIF
    try
        info = imfinfo(name);
        % Check if there is a 'Orientation' field
        if isfield(info, 'Orientation')
            orientation = info.Orientation;
        else
            orientation = 1; % Set to normal direction by default
        end
    catch
        orientation = 1; % If information retrieval fails, set to the normal direction
    end
    
    corrected_img = OrienRota(img,orientation);
    img = corrected_img;

    [m,n,r]=size(img); % % m is the pixel-number in the y direction (width) 
    % , n is the pixel-number in the x direction (length)

    global fig ax pointCount points pointMarkers lineObjs done;

    fig = figure('Name',strcat('Select the corners of the box No.',num2str(i),'.'), ...
             'NumberTitle','off', 'Position', ...
             [windowX, windowY, windowWidth, windowHeight]);
    
    % ------- Select four corner points -------
    % Initialize variables
    points = zeros(4, 2); % Store the coordinates of four points
    pointCount = 0; % Number of points already selected
    pointMarkers = gobjects(4, 1); % Storage dot graphic objects
    lineObjs = gobjects(4,1); % Storage line graphic objects
    done = false; % Mark of comleting the selection
    ax = axes('Parent',fig,'Position',[0.05 0.05 0.9 0.9]);
    imshow(img,'Parent',ax);
    
    set(fig,'KeyPressFcn',@keyPressCallback);
    set(fig,'WindowButtonDownFcn',@mouseClickCallback);

    % Wait for the user to complete the selection
    while ~done
        pause(0.1);
    end
    corner_points(:,:,i) = points;

     % --- Obtain the size of the target frame ---
    leftdown = int16(points(1,:));rightdown = int16(points(2,:));
    leftup = int16(points(3,:));rightup = int16(points(4,:));
    frame_n(i) = round(mean( (rightup(1)-leftup(1)), (rightdown(1)-leftdown(1)) ));
    frame_m(i) = round(mean( (leftup(2)-leftdown(2)), (rightup(2)-rightdown(2)) ));

end



% -----------------------------------
% ------------ MAIN LOOP ------------
% -----------------------------------

for i = 1:k
    % % disp(i);
    clear warped_img
    clear char

    % --- Straighten the rock core boxes ---
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
    
    corrected_img = OrienRota(img,orientation);
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

    % --- Make title pics ---
    title = zeros(round(frame_n(i)*0.0625),frame_n(i),3,'uint8');
    title(:,:,1) = 253; % yellow background srgb(0,253,253)
    title(:,:,2) = 253;
    [m2,n2,l2] = size(title); % m2 is the pixel-number in the y-direction
    m2 = int16(m2);n2 = int16(n2); l2 = int16(l2);

    titlename = char(txt{i});
    titlelen = length(titlename);
    FontHeight = m2-60;
    ydiff = int16((m2-FontHeight)*0.5);
    totalX = round(n*0.05);
    % Back word matrix
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
    
        [Wordy,Wordx,Wordz] = size(WM); % Wordy is the pixel number of y-direction
        FontWidth = int16( double(FontHeight) / Wordy * Wordx );
        WMa = imresize(WM, [FontHeight, FontWidth]);% word matrix adopted
        WMa(WMa>100) = 255; % Remove some black spots
        
        title(ydiff+1:ydiff+FontHeight,totalX+1:totalX+FontWidth,:) = WMa;
        totalX = totalX + FontWidth;
    end

    % --- Combine the rock core photo and title pic ---

    answer = cat(1,title,warped_img); % the Result
    % imshow(answer);
    name = strcat(foldername,'\',titlename,'.jpg');
    imwrite(answer, name, Quality=95); % save it

    disp(strcat('Box No.',num2str(i),' is completed.'));
end

% --------------------------------------
% ------------ MAIN LOOP END ------------
% --------------------------------------

close all;
disp('ALL DONE');
box = msgbox('ALL DONE.');
txtdone = findall(box, 'Type', 'text');
set(txtdone, 'FontSize', 11); 
jButton = findobj(box, 'Style', 'pushbutton');
set(jButton, 'FontSize', 10); % 设置字体大小为 10



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

% 根据 orientation 值旋转图像
function corrected_img = OrienRota(img,orientation)
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
end

function txt = RenamePics(Bnum, input, Bname)
global kongshen
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
end
