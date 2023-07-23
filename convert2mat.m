% Create mat files from the p files
%
% June-2023, Pat Welch, pat@mousebrains.com
%
%%

function filenames = convert2mat(filenames)
arguments
    filenames table
end % arguments
%%
% Use odas_p2mat to generate a mat file version of each pfile

for index = 1:size(filenames,1)
    row = filenames(index,:);
    fnP = row.fnP; % Filename of p file
    if ~row.qUse
        % fprintf("Not using %s\n", fnP);
        continue;
    end % if ~qUse
    fnM = row.fnM; % Filename of resulting mat file
    if isnewer(fnM, fnP)
        % fprintf("Newer %s\n", fnM)
        continue;
    end % if isnewer
    stime = tic();
    myMkDir(fnM); % Make the directory if needed
    try
        a = odas_p2mat(char(fnP)); % extract P file contents
        save(row.fnM, "-struct", "a"); % save into a mat file
        fprintf("Took %.2f seconds to convert %s %s\n", toc(stime), row.sn, row.basename);
    catch ME
        filenames.qUse(index) = false;
        fprintf("Failed to convert %s\n%s\n%s\n", fnP, ME.identifier, ME.message);
        for i = 1:numel(ME.stack)
            item = ME.stack(i);
            fprintf("Line %d %s -> %s\n", item.line, item.name, item.file);
        end % for i
    end % try catch
end % for index
end % convert2mat