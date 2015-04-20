function [ts] = time_to_timestamp(time_vec)
ts = [num2str(time_vec(1)) '-' num2str(time_vec(2)) '-' num2str(time_vec(3)) ...
    ' ' num2str(time_vec(4)) ':' num2str(time_vec(5)) ':' num2str(time_vec(6)) ];
end