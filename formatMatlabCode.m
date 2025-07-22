function formatMatlabCode(inputFile, outputFile)
%FORMATMATLABCODE 格式化 MATLAB 源代码文件，提升可读性，包括减号空格特殊处理
%   formatMatlabCode(inputFile)
%   formatMatlabCode(inputFile, outputFile)

if nargin < 1
    error('必须提供输入文件名');
end
if nargin < 2
    outputFile = inputFile;
end

try
    fileContent = fileread(inputFile);
    lines = splitlines(fileContent);
catch
    error('无法读取文件: %s', inputFile);
end

operators = { '==', '~=', '<=', '>=', '.*', './', '.^', '^' ...
    '<', '>', '=', '+', '-', '*', '/', '\', ...
    '&', '|', '&&', '||', ','};

for i = 1:length(lines)
    originalLine = lines{i};
    if isempty(strtrim(originalLine))
        continue;
    end

    % 找注释位置，忽略字符串内的 %
    inString = false;
    commentPos = 0;
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

    formattedCode = codePart;
    if ~isempty(formattedCode)
        % 字符串掩码
        stringMask = false(1, length(formattedCode));
        inString = false;
        for j = 1:length(formattedCode)
            if formattedCode(j) == '''' && (j == 1 || formattedCode(j-1) ~= '\')
                inString = ~inString;
            end
            stringMask(j) = inString;
        end

        operatorMask = false(1, length(formattedCode));
        [~, sortIdx] = sort(cellfun(@length, operators), 'descend');
        sortedOperators = operators(sortIdx);

        for opIdx = 1:length(sortedOperators)
            op = sortedOperators{opIdx};
            opLen = length(op);
            pattern = regexptranslate('escape', op);

            if strcmp(op, '-')
                % 跳过，交给自定义减号处理函数
                continue;
            else
                matchPos = regexp(formattedCode, pattern);
            end

            for m = length(matchPos):-1:1
                idx = matchPos(m);
                if idx + opLen - 1 > length(formattedCode)
                    continue;
                end

                if any(stringMask(idx:idx+opLen-1)) || ...
                        any(operatorMask(idx:idx+opLen-1))
                    continue;
                end

                if idx > 1 && ~isspace(formattedCode(idx - 1))
                    formattedCode = [formattedCode(1:idx - 1), ' ', formattedCode(idx:end)];
                    stringMask = [stringMask(1:idx - 1), false, stringMask(idx:end)];
                    operatorMask = [operatorMask(1:idx - 1), false, operatorMask(idx:end)];
                    idx = idx + 1;
                end

                opEnd = idx + opLen - 1;
                if opEnd < length(formattedCode) && ~isspace(formattedCode(opEnd + 1))
                    formattedCode = [formattedCode(1:opEnd), ' ', formattedCode(opEnd + 1:end)];
                    stringMask = [stringMask(1:opEnd), false, stringMask(opEnd + 1:end)];
                    operatorMask = [operatorMask(1:opEnd), false, operatorMask(opEnd + 1:end)];
                end

                operatorMask(idx:idx+opLen-1) = true;
            end
        end

        % 调用改进版减号空格处理函数
        formattedCode = formatMinusSpacing(formattedCode, stringMask);

        % 逗号处理
        commaPos = find(formattedCode == ',');
        for k = length(commaPos):-1:1
            pos = commaPos(k);
            if ~stringMask(pos)
                if pos > 1 && isspace(formattedCode(pos-1))
                    formattedCode = [formattedCode(1:pos-2) formattedCode(pos:end)];
                    pos = pos - 1;
                end
                if pos < length(formattedCode) && ~isspace(formattedCode(pos+1))
                    formattedCode = [formattedCode(1:pos) ' ' formattedCode(pos+1:end)];
                end
            end
        end

        % 分号处理
        semicolonPos = find(formattedCode == ';');
        for k = length(semicolonPos):-1:1
            pos = semicolonPos(k);
            if pos <= length(stringMask) && ~stringMask(pos) && pos < length(formattedCode) && ~isspace(formattedCode(pos+1))
                formattedCode = [formattedCode(1:pos) ' ' formattedCode(pos+1:end)];
            end
        end
    end

    % 注释格式化
    formattedComment = commentPart;
    if ~isempty(formattedComment)
        percentPositions = find(formattedComment == '%');
        if ~isempty(percentPositions)
            isSectionComment = (length(percentPositions) >= 2) && ...
                (percentPositions(2) == percentPositions(1)+1);

            if isSectionComment
                lastPercent = percentPositions(end);
                if lastPercent < length(formattedComment) && formattedComment(lastPercent+1) ~= ' '
                    formattedComment = [formattedComment(1:lastPercent) ' ' formattedComment(lastPercent+1:end)];
                end
            else
                for k = length(percentPositions):-1:1
                    pos = percentPositions(k);
                    if pos < length(formattedComment) && formattedComment(pos+1) ~= ' '
                        formattedComment = [formattedComment(1:pos) ' ' formattedComment(pos+1:end)];
                    end
                end
            end
        end
    end

    newLine = [formattedCode, formattedComment];
    if ~strcmp(strtrim(newLine), strtrim(originalLine))
        lines{i} = newLine;
    else
        lines{i} = originalLine;
    end
end

try
    fid = fopen(outputFile, 'w', 'n', 'UTF-8');
    for i = 1:length(lines)
        if i < length(lines)
            fprintf(fid, '%s\n', lines{i});
        else
            fprintf(fid, '%s', lines{i});
        end
    end
    fclose(fid);
    fprintf('✅ 成功格式化并保存到: %s\n', outputFile);
catch ME
    if exist('fid', 'var') && fid ~= -1
        fclose(fid);
    end
    error('写入失败: %s\n错误信息: %s', outputFile, ME.message);
end
end

% =============== 修改后的减号空格处理函数 ==================
function formattedLine = formatMinusSpacing(line, stringMask)
n = length(line);
if nargin < 2
    stringMask = false(1,n);
    inString = false;
    for i = 1:n
        if line(i) == '''' && (i == 1 || line(i-1) ~= '\')
            inString = ~inString;
        end
        stringMask(i) = inString;
    end
end

i = 1;
while i <= n
    if ~stringMask(i) && line(i) == '-'
        isNegative = false;
        if i == 1 || isspace(line(i-1)) || any(line(i-1) == '=,;:+-*/\<>()[]{}~&|^!')
            if i < n && ( ...
                    (line(i+1) >= '0' && line(i+1) <= '9') || ...
                    line(i+1) == '.' || ...
                    line(i+1) == '''' || ...
                    ((line(i+1) >= 'a' && line(i+1) <= 'z') || (line(i+1) >= 'A' && line(i+1) <= 'Z') || line(i+1) == '_') )
                isNegative = true;
            end
        end

        if ~isNegative
            if i > 1 && ~isspace(line(i-1)) && ~any(line(i-1) == '+-*/=,<>&|^~([{:;')
                line = [line(1:i-1), ' ', line(i:end)];
                stringMask = [stringMask(1:i-1), false, stringMask(i:end)];
                i = i + 1;
                n = n + 1;
            end
            if i < n && ~isspace(line(i+1)) && ~any(line(i+1) == '+-*/=,<>&|^~)]}:;,''"')
                line = [line(1:i), ' ', line(i+1:end)];
                stringMask = [stringMask(1:i), false, stringMask(i+1:end)];
                n = n + 1;
            end
        end
    end
    i = i + 1;
end
formattedLine = line;
end
