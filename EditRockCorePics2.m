clc;clear;close all;

% ----------------------------------------------------------------------------
%  使用说明：                                                               
% ----------------------------------------------------------------------------
% 
% 1）流程为：
%    编辑<输入参数.txt> --> 运行本脚本 --> 选取岩芯照片 --> 选取每张岩芯照片的四个角点
%    --> 等待自动生成带有标题的岩芯照片 --> 在titled文件夹中查看结果
%
% 2）输入参数的格式：
% 	在<输入参数.txt>文件中，
% 	第一行输入钻孔编号，
% 	第二行输入岩芯箱总数，
%	换行后每行输入每箱岩芯结束的孔深。
% 
% 例如：假设有ZK07，共4箱，每箱结束的孔深为5、10、15、19.5m。则在<输入参数.txt>文件中输入：
% 	ZK07
% 	4
% 	5
% 	10
% 	15
% 	19.5
%
% 3）岩芯照片顺序：
% 	岩芯照片在文件夹中必须按箱号从小到大排列。
% 
% 4）选取岩芯箱四个角时的操作：
%  a.点击岩芯箱四个角时，必须遵守顺序为左上、右上、左下、右下。
%  b.鼠标左键为选择; 
%    右键为取消上一个点; 
%    空格为确认四个点，进入下一张照片。
% ----------------------------------------------------------------------------



% --------- 读取输入参数 ---------
input = readcell('输入参数.txt');
Bname = char(input{1}) ; % 钻孔编号
Bnum = int8(input{2}) ; % 岩芯箱总数
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
            if(kongshen(i-1)==round(kongshen(i-1)))% 前整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'.0m～',num2str(kongshen(i)),'.0m'));
            else% 前不整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'m～',num2str(kongshen(i)),'.0m'));
            end
        else% 后不整
            if(kongshen(i-1)==round(kongshen(i-1)))% 前整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'.0m～',num2str(kongshen(i)),'m'));
            else% 前不整
                txt(i) = cellstr(strcat(Bname,' 第',num2str(i),'箱 孔深：',num2str(kongshen(i-1)),'m～',num2str(kongshen(i)),'m'));
            end
        end
    end
end

jpgnames = uigetfile(fullfile(pwd,'\*.*'),'MultiSelect','on');
k = length(jpgnames);
if (k~=Bnum)
    disp('岩芯箱数与照片总数不相等.');
    return
end

% 创建文件夹titled，放置加好抬头的岩芯照片
foldername = fullfile(pwd,'titled');
if ~exist(foldername,'dir')
    mkdir(foldername);
else
    disp('titled-dir already exists');
end

frame_m = int16(zeros(1,k));frame_n = int16(zeros(1,k));
corner_points = zeros(4,2,k);


% -----------------------------
% -------- 得到四角点位置 --------
% -----------------------------

for i = 1:k
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

    global fig ax pointCount points pointMarkers lineObjs done;

    fig = figure('Name','选取岩芯箱四个角：', ...
             'NumberTitle','off', 'Position',[100 100 1000 700]);
    
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



% --------------------------------
% ------------ 主 循 环 ------------
% --------------------------------

for i = 1:k
    disp(i);
    clear warped_img

    % --- 把岩芯箱平直化 ---
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

    % --- 做抬头照片 ---
    title = zeros(round(frame_n(i)*0.0625),frame_n(i),3,'uint8');
    title(:,:,1) = 253; % 黄色背景srgb(0,253,253)
    title(:,:,2) = 253;
    [m2,n2,l2] = size(title); % m2为抬头照片的y方向像素数（宽）
    m2 = int16(m2);n2 = int16(n2); l2 = int16(l2);
    imshow(title);
    x = round(frame_n(i)*0.05) ;  % 字的位置x方向
    y = round(frame_n(i)*0.03) ;  % 字的位置y方向
    titlename = char(txt(i));
    fontsize = round(frame_n(i)*0.011); % 字体大小
    
    text(x,y,titlename,'color',[1,0,0], ...
        'FontName', '黑体','FontSize',fontsize) 
    set(gcf,'Position',[0,0,n2,m2]);
    exportgraphics(gca,'zhongzhuan.jpg',Resolution=300);

    % --- 调整抬头照片 ---
    title2 = imread('zhongzhuan.jpg'); % 读做好的抬头照片
    [mm,nn,ll] = size(title2);
    mdiff = round((mm-m2)*0.5); % y方向抬头与岩芯照片的像素数差值的一半
    ndiff = round((nn-n2)*0.5);

    if (ndiff >30) % 调整文字位置
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
    if(mdiff<0) % 原照片比较窄的情况
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

    % 将抬头照片x方向长度像素大小与岩芯照片x方向长度像素大小对齐
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
    
    % --- 将抬头照片与岩芯照片拼起来 ---
    % title3 = title2(mdiff:mend,ndiff:nend,:); % 取x方向中间的部分

    if (ndiff>10)
        title3 = title2(mdiff:mend,10:nend-ndiff+10,:); % 取x方向前面的部分
    else
        title3 = title2(mdiff:mend,1:nend-ndiff+1,:); % 取x方向前面的部分
    end

    answer = cat(1,title3,warped_img); % 最终结果
    imshow(answer);
    name = strcat(foldername,'\',titlename,'.jpg');
    imwrite(answer, name, Quality=95); % 保存图片

    disp(i);

end

% -------------------------------------
% ------------ 主 循 环 结 束 ------------
% -------------------------------------

close all;
delete('zhongzhuan.jpg');
disp('ALL DONE');


% 鼠标点击回调函数
function mouseClickCallback(~, ~)
    
    global fig ax pointCount points pointMarkers lineObjs;

    % 获取点击类型
    clickType = get(fig, 'SelectionType');
    
    % 左键点击 - 添加点
    if strcmp(clickType, 'normal')
        % 检查是否已经选择了4个点
        if pointCount >= 4
            msgbox('已经选择了4个点，不能再添加更多点。', '提示', 'warn');
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
            msgbox('没有可取消的点。', '提示', 'help');
        end
    end
end

% 键盘按键回调函数
function keyPressCallback(~, event)
    global fig done;
    % 空格键 - 结束选择
    if strcmp(event.Key, 'space')
        done = true;
        close(fig);
    end
end


