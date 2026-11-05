function [units, cfg] = plan(cfg)
if isempty(cfg.work_dir)
    cfg.work_dir = fullfile(cfg.output_dir, '..', 'work');
end
units = struct('id', {'u1', 'u2', 'u3'}, 'input', cfg.input_file);
end
