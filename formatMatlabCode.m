function formatMatlabCode(inputFile, outputFile)
% 功能：美化代码，在'='等地方添加一些空格
% 输入：需要格式化的文件路径；输出：处理后的文件路径。

% 检查输入参数
if nargin < 1
    error('必须提供输入文件名');
end
if nargin < 2
    outputFile = inputFile; % 默认覆盖原文件
end

% 读取文件内容
try
    fileContent = fileread(inputFile);
    lines = splitlines(fileContent);
catch
    error('无法读取文件: %s', inputFile);
end

% 运算符定义（需要加空格的符号）
operators = { '==', '~=', '<', '>', '<=', '>=','=', ...
    '+', '-', '*', '/', '\', ...
    '&', '|', '&&', '||', ','};

% 处理每一行
for i = 1:length(lines)
    originalLine = lines{i};
    if isempty(strtrim(originalLine))
        continue; % 跳过空行
    end

    % ==== 分割代码和注释部分 ====
    inString = false;
    commentPos = 0;
    % 查找第一个不在字符串中的%符号
    for j = 1:length(originalLine)
        if originalLine(j) == '''' && (j == 1 || originalLine(j-1) ~= '\')
            inString = ~inString;
        elseif ~inString && originalLine(j) == '%'
            commentPos = j;
            break;
        end
    end

    if commentPos > 0
        codePart = originalLine(1:commentPos-1);
        commentPart = originalLine(commentPos:end);
    else
        codePart = originalLine;
        commentPart = '';
    end

    % ==== 格式化代码部分 ====
    formattedCode = codePart;
    if ~isempty(formattedCode)
        % 创建字符串掩码
        stringMask = false(1, length(formattedCode));
        inString = false;
        for j = 1:length(formattedCode)
            if formattedCode(j) == '''' && (j == 1 || formattedCode(j-1) ~= '\')
                inString = ~inString;
            end
            stringMask(j) = inString;
        end


        % === 初始化运算符掩码，标记已经处理的位置 ===
        operatorMask = false(1, length(formattedCode));

        % 按运算符长度从长到短排序（只需一次）
        [~, sortIdx] = sort(cellfun(@length, operators), 'descend');
        sortedOperators = operators(sortIdx);

        % === 正确处理运算符：跳过字符串和已处理的区域 ===
        for opIdx = 1:length(sortedOperators)
            op = sortedOperators{opIdx};
            opLen = length(op);
            pattern = regexptranslate('escape', op);
            matchPos = regexp(formattedCode, pattern);

            for m = length(matchPos):-1:1
                idx = matchPos(m);
                if idx + opLen - 1 > length(formattedCode)
                    continue; % 超出边界
                end

                % 检查是否在字符串中或已处理
                if any(stringMask(idx:idx+opLen-1)) || ...
                        any(operatorMask(idx:idx+opLen-1))
                    continue;
                end

                % === 插入前后空格（如果需要） ===
                % 前面插空格
                if idx > 1 && ~isspace(formattedCode(idx - 1))
                    formattedCode = [formattedCode(1:idx - 1), ' ', formattedCode(idx:end)];
                    stringMask = [stringMask(1:idx - 1), false, stringMask(idx:end)];
                    operatorMask = [operatorMask(1:idx - 1), false, operatorMask(idx:end)];
                    idx = idx + 1;
                end

                % 后面插空格
                opEnd = idx + opLen - 1;
                if opEnd < length(formattedCode) && ~isspace(formattedCode(opEnd + 1))
                    formattedCode = [formattedCode(1:opEnd), ' ', formattedCode(opEnd + 1:end)];
                    stringMask = [stringMask(1:opEnd), false, stringMask(opEnd + 1:end)];
                    operatorMask = [operatorMask(1:opEnd), false, operatorMask(opEnd + 1:end)];
                end

                % 标记已处理位置
                operatorMask(idx:idx+opLen-1) = true;
            end
        end
        
        % 处理逗号（前无空格，后有空格）
        commaPos = find(formattedCode == ',');
        for k = length(commaPos):-1:1
            pos = commaPos(k);
            if ~stringMask(pos)
                % 删除前面的空格
                if pos > 1 && isspace(formattedCode(pos-1))
                    formattedCode = [formattedCode(1:pos-2) formattedCode(pos:end)];
                    pos = pos - 1;
                end
                % 添加后面的空格
                if pos < length(formattedCode) && ~isspace(formattedCode(pos+1))
                    formattedCode = [formattedCode(1:pos) ' ' formattedCode(pos+1:end)];
                end
            end
        end
        % 处理分号（后有空格，行尾除外）
        semicolonPos = find(formattedCode == ';');
        for k = length(semicolonPos):-1:1
            pos = semicolonPos(k);
            if pos <= length(stringMask) && ~stringMask(pos) && pos < length(formattedCode) && ~isspace(formattedCode(pos+1))
                formattedCode = [formattedCode(1:pos) ' ' formattedCode(pos+1:end)];
            end
        end
    end


    % ==== 改进的注释处理部分 ====
    formattedComment = commentPart;
    if ~isempty(formattedComment)
        % 查找所有%位置
        percentPositions = find(formattedComment == '%');

        if ~isempty(percentPositions)
            % 判断是否为节注释（连续%%开头）
            isSectionComment = (length(percentPositions) >= 2) && ...
                (percentPositions(2) == percentPositions(1)+1);

            if isSectionComment
                % 节注释处理：在最后一个%后加空格
                lastPercent = percentPositions(end);
                if lastPercent < length(formattedComment) && formattedComment(lastPercent+1) ~= ' '
                    formattedComment = [formattedComment(1:lastPercent) ' ' formattedComment(lastPercent+1:end)];
                end
            else
                % 普通注释处理：该行所有%后都加空格
                % 从后往前处理，避免索引问题
                for k = length(percentPositions):-1:1
                    pos = percentPositions(k);
                    if pos < length(formattedComment) && formattedComment(pos+1) ~= ' '
                        formattedComment = [formattedComment(1:pos) ' ' formattedComment(pos+1:end)];
                    end
                end
            end
        end
    end

    % ==== 组合结果 ====
    newLine = [formattedCode, formattedComment];
    % 只有当确实有变化时才更新
    if ~strcmp(strtrim(newLine), strtrim(originalLine))
        lines{i} = newLine;
    else
        lines{i} = originalLine;
    end
end

% 写入输出文件
try
    fid = fopen(outputFile, 'w');
    for i = 1:length(lines)
        if i < length(lines)
            fprintf(fid, '%s\n', lines{i});
        else
            fprintf(fid, '%s', lines{i}); % 最后一行不加额外换行
        end
    end
    fclose(fid);
    fprintf('成功格式化代码并保存到: %s\n', outputFile);
catch ME
    if exist('fid', 'var') && fid ~= -1
        fclose(fid);
    end
    error('写入文件失败: %s\n错误: %s', outputFile, ME.message);
end
end
