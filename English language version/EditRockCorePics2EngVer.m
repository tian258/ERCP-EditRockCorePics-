clc;clear;close all;

% ----------------------------------------------------------------------------
%  Instruction:                                                               
% ----------------------------------------------------------------------------
% 
% (1) Work flow：
%   --> Edit<InputPara.txt> 
%   --> Run EditRockCorePics2.m file 
%   --> Select rock core photos
%   --> Select 4 corner points of the box for each photo
%   --> Waiting for automatic generation of images with titles 
%   --> check the photos in the folder "titled"
%
% (2) Format of input parameters：
% In the file <InputPara.txt>,
% The first line is the drill hole name.
% The second line is the total number of rock core boxes.
% After the line breaks, each line represents the hole-depth at the end of
% each box.
% 
% For example：Assuming there are 4 boxes of drill hole ZK07, with 
% hole-depths of 5m, 10m, 15m, and 19.5m at the end of boxes. 
% Then in the <InputPara.txt> file, write:
% ZK07
% 4
% 5
% 10
% 15
% 19.5
%
% (3) Order of rock core photos：
% Rock core photos must be arranged in ascending order in the folder.
% 
% (4) Operations when selecting 4 corner points of the boxes：
%  a. When clickinging the four corners of the boxes, must follow the 
%  order: top left, top right, bottom left, and bottom right.
%  b. Left mouse button click for selection;  
%  Right-click to cancel the previous one point;  
%  Press the space bar to confirm the 4 points and go on to the next box.
% ----------------------------------------------------------------------------



% --------- Read input parameters ---------
input = readcell('InputPara.txt');
Bname = char(input{1}) ; % Drill hole name 
Bnum = int8(input{2}) ; % Total number of boxes
kongshen = zeros(1,Bnum);

% ------ Edit titles -----
txt = num2cell(zeros(1,Bnum)); % Rename the photos
for i = 1:Bnum
    kongshen(i) = input{i+2};
    if(i==1)
        if(kongshen(i)==round(kongshen(i))) % the later is int
            txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：','0.0m～',num2str(kongshen(i)),'.0m'));
        else
            txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：','0.0m～',num2str(kongshen(i)),'m'));
        end
    else
        if(kongshen(i)==round(kongshen(i))) % the later is int
            if(kongshen(i-1)==round(kongshen(i-1)))% the former is int
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'.0m～',num2str(kongshen(i)),'.0m'));
            else% the former is no int
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'m～',num2str(kongshen(i)),'.0m'));
            end
        else% the later is no int
            if(kongshen(i-1)==round(kongshen(i-1)))% the former is int
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'.0m～',num2str(kongshen(i)),'m'));
            else% the former is no int
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'m～',num2str(kongshen(i)),'m'));
            end
        end
    end
end

jpgnames = uigetfile(fullfile(pwd,'\*.*'),'MultiSelect','on');
k = length(jpgnames);
if (k~=Bnum)
    disp('The total number of boxes no match the number of photos.');
    return
end

% Create a folder "titled" and place the final photos there
foldername = fullfile(pwd,'titled');
if ~exist(foldername,'dir')
    mkdir(foldername);
else
    disp('folder "titled" already exists');
end

frame_m = int16(zeros(1,k));frame_n = int16(zeros(1,k));
corner_points = zeros(4,2,k);

% -------- Get four corner points --------
for i = 1:k
    name = char(jpgnames{i});
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
    
    % Rotate the image according to the orientation value
    switch orientation
        case 1 % Normal
            corrected_img = img; % No need to rotate
        case 2 % Horizontal flipping (seldom seen)
            corrected_img = flip(img, 2); % Flip along the vertical axis
        case 3 % Rotate 180 degrees
            corrected_img = rot90(img, 2); % 旋转 180 度
        case 4 % Vertical flipping (seldom seen)
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
    [m,n,r]=size(img); % m is the pixel-number in the y direction (width) 
    % , n is the pixel-number in the x direction (length)

    global fig ax pointCount points pointMarkers lineObjs done;

    fig = figure('Name','Select four corners of the box：', ...
             'NumberTitle','off', 'Position',[100 100 1000 700]);
    
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

% ------- Main loop -------
for i = 1:k
    disp(i);
    clear warped_img

    % --- Straighten the rock core boxes ---
    name = char(jpgnames{i});
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
    imshow(title);
    x = round(frame_n(i)*0.05) ;  % Position of words in x-direction
    y = round(frame_n(i)*0.03) ;  % Position of words in y-direction
    titlename = char(txt(i));
    fontsize = round(frame_n(i)*0.011);
    
    text(x,y,titlename,'color',[1,0,0], ...
        'FontName', '黑体','FontSize',fontsize) 
    set(gcf,'Position',[0,0,n2,m2]);
    exportgraphics(gca,'zhongzhuan.jpg',Resolution=300);

    % --- Adjust the title photo ---
    title2 = imread('zhongzhuan.jpg'); % Read the title photo
    [mm,nn,ll] = size(title2);
    mdiff = round((mm-m2)*0.5); % Half of the pixel-number difference 
    % between the title photo and the rock core photo in y-direction
    
    ndiff = round((nn-n2)*0.5);

    if (ndiff >30) % Adjust the position of the words
        Reso = round(300-ndiff*0.05);
        imshow(title);
        text(x,y,titlename,'color',[1,0,0], ...
            'FontName', '黑体','FontSize',fontsize)
        set(gcf,'Position',[0,0,n2,m2]);
        exportgraphics(gca,'zhongzhuan.jpg',Resolution=Reso);

        title2 = imread('zhongzhuan.jpg');
        [mm,nn,ll] = size(title2);
        mm = int16(mm);nn = int16(nn); ll = int16(ll);
        mdiff = round((mm-m2)*0.5);
        ndiff = round((nn-n2)*0.5);
    elseif (ndiff<0) 
        Reso = round(300-ndiff);
        imshow(title);
        fontsize = fontsize * 0.9;
        text(x,y,titlename,'color',[1,0,0], ...
            'FontName', '黑体','FontSize',fontsize)
        set(gcf,'Position',[0,0,n2,m2]);
        exportgraphics(gca,'zhongzhuan.jpg',Resolution=Reso);

        title2 = imread('zhongzhuan.jpg');
        [mm,nn,ll] = size(title2);
        mm = int16(mm);nn = int16(nn); ll = int16(ll);
        mdiff = round((mm-m2)*0.5);
        ndiff = round((nn-n2)*0.5);
    end
    if(mdiff<0) % When photo is narrow
        Reso2 = round(300-mdiff);
        imshow(title);
        fontsize = fontsize * 0.9;
        text(x,y,titlename,'color',[1,0,0], ...
            'FontName', '黑体','FontSize',fontsize)
        set(gcf,'Position',[0,0,n2,m2]);
        exportgraphics(gca,'zhongzhuan.jpg',Resolution=Reso2);

        title2 = imread('zhongzhuan.jpg');
        [mm,nn,ll] = size(title2);
        mm = int16(mm);nn = int16(nn); ll = int16(ll);
        mdiff = round((mm-m2)*0.5);
        ndiff = round((nn-n2)*0.5);
    end

    % Align the pixel-numbers in x-direction
    if (mm-mdiff*2+1-m2 ~= 0)
        mend = mm-mdiff-1;
    else
        mend = mm-mdiff;
    end
    if (nn-ndiff*2+1-n2 ~= 0)
        nend = nn-ndiff-1;
    else
        nend = nn-ndiff;
    end
    
    % --- Combine the rock core photo and title pic ---
    % title3 = title2(mdiff:mend,ndiff:nend,:); % 取x方向中间的部分

    if (ndiff>10)
        title3 = title2(mdiff:mend,10:nend-ndiff+10,:); % 取x方向前面的部分
    else
        title3 = title2(mdiff:mend,1:nend-ndiff+1,:); % 取x方向前面的部分
    end

    answer = cat(1,title3,warped_img); % 最终结果
    imshow(answer);
    name = strcat(foldername,'\',name);
    imwrite(answer, name, Quality=95); % 保存图片

    disp(i);

end


close all;
disp('ALL DONE');


% Mouse click callback function
function mouseClickCallback(~, ~)
    
    global fig ax pointCount points pointMarkers lineObjs;

    % Get the type of click
    clickType = get(fig, 'SelectionType');
    
    % left click - select
    if strcmp(clickType, 'normal')
        % 检查是否已经选择了4个点
        if pointCount >= 4
            % msgbox('已经选择了4个点，不能再添加更多点。', '提示', 'warn');
            return;
        end
        
        % Get the current coordinates
        currentPoint = get(ax, 'CurrentPoint');
        x = currentPoint(1,1);
        y = currentPoint(1,2);
        
        % Add a new point
        pointCount = pointCount + 1;
        points(pointCount, 1) = x;
        points(pointCount, 2) = y;
        
        % Draw the dot
        hold(ax, 'on');
        pointMarkers(pointCount) = plot(ax, x, y, 'ro', 'MarkerSize', ...
                                    10, 'LineWidth', 2);
        hold(ax, 'off');
        
        % If there is 4 points, draw the lines.
        if pointCount == 4
            % Clear previous lines
            delete(lineObjs(ishandle(lineObjs)));
            
            % draw new lines( connect 1-2, 1-3, 3-4, 2-4th points)
            hold(ax, 'on');
            
            % line1: point1 → point2
            lineObjs(1) = plot(ax, [points(1,1), points(2,1)], ...
                         [points(1,2), points(2,2)], 'g-', 'LineWidth', 1);
            
            % line2: point1 → point3
            lineObjs(2) = plot(ax, [points(1,1), points(3,1)], ...
                         [points(1,2), points(3,2)], 'g-', 'LineWidth', 1);
            
            % line3: point2 → point4
            lineObjs(3) = plot(ax, [points(2,1), points(4,1)], ...
                         [points(2,2), points(4,2)], 'g-', 'LineWidth', 1);
            
            % line4: point3 → point4
            lineObjs(4) = plot(ax, [points(3,1), points(4,1)], ...
                         [points(3,2), points(4,2)], 'g-', 'LineWidth', 1);
            
            hold(ax, 'off');
        end
        
        % 更新状态
        % set(infoText, 'String', sprintf('已选点: %d/4', pointCount));
        
     % Right click - cancel the last selected point
    elseif strcmp(clickType, 'alt')
        % Check if there is a point to be cancelled
        if pointCount > 0
            % delete the object of the last selected point
            if ishandle(pointMarkers(pointCount))
                delete(pointMarkers(pointCount));
            end
            
            % Clear the coordinate of the point
            points(pointCount, :) = [0, 0];
            
            % Reduce the count of points
            pointCount = pointCount - 1;
            
            % Clear all connections (as the order of points may change)
            delete(lineObjs(ishandle(lineObjs)));
            lineObjs = gobjects(4, 1);
            
            % % % 如果还有足够的点，重新绘制连线
            % % if pointCount >= 2
            % %     % 这里可以根据需要添加部分连线的绘制逻辑
            % %     % 但由于连线方式依赖于四个点的特定组合，我们只在有四个点时绘制完整连线
            % % end
            
            % 更新状态
            % set(infoText, 'String', sprintf('已选点: %d/4', pointCount));
        else
            % msgbox('没有可取消的点。', '提示', 'help');
        end
    end
end

% Function of key press call back
function keyPressCallback(~, event)
    global fig done;
    % Space key press - finish the selection
    if strcmp(event.Key, 'space')
        done = true;
        close(fig);
    end
end


