function theStructs = ReadStructsFromTextW(filename, delimiter)

    % Open the file
    fid = fopen(filename);
    if (fid == -1)
        error('Cannot open file %s', filename);
    end

    if (nargin < 2)  ||  isempty(delimiter)
        delimiter = sprintf('\t');
    end

    % Make sure the delimiter is a single character
    if ~ischar(delimiter)  ||  length(delimiter) ~= 1
        error('delimiter format incorrect');
    end

    % =====================================================================
    % Process the first line to get field names

    % Get first line
    tline = fgetl(fid);

    % Find the delimiters
    delimIdx = strfind(tline, delimiter);
    % pretend there's one at the beginning and at the end
    delimIdx = [0  delimIdx  length(tline)+1];

    % Preallocate cell array for fields
    fields = cell(1,length(delimIdx));
    % Get the names of the fields
    for i = 1:length(delimIdx)-1

        % Find the starting point and ending point for the current field
        %(don't include the delimiters)
        startOffset = delimIdx(i)+1;
        endOffset   = delimIdx(i+1)-1;

        % Get the name
        fieldName = tline(startOffset:endOffset);

        % Remove whitespace
        fieldName = regexprep(fieldName, '\W', '');

        % Store it
        fields{i} = fieldName;

    end

    % ======================================================================
    % Process every line of text
    lineCount = 1;
    while 1

        % Get a line from the input file
        tline = fgetl(fid);

        % Quit if EOF reached
        if ~ischar(tline)
            if ~exist('theStructs','var')
                theStructs=[];
            end
            break
        end

        % Find the delimiters
        delimIdx = strfind(tline, delimiter);

        % pretend there's one at the beginning - this is used later
        delimIdx = [0  delimIdx length(tline)+1];

        % Process each element
        for i = 1:length(delimIdx)-1

            % Find the starting point and ending point for the current field
            %(don't include the delimiters)
            startOffset = delimIdx(i)+1;
            endOffset   = delimIdx(i+1)-1;

            % Get the element
            txt = tline(startOffset:endOffset);

            % attempt conversion to number
            [num tmp errmsg] = sscanf(txt, '%f');

            % Number conversion successful if no error message
            if isempty(errmsg)
                theStructs(lineCount).(fields{i}) = num;
            else
                theStructs(lineCount).(fields{i}) = txt;
            end

        end

        lineCount = lineCount + 1;
    end

    fclose(fid);

end