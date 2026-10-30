function result = run_unit(unit, cfg, log)
% Each step appends its name to <output_dir>/calls/<unit>.txt and
% writes a file into the work folder, so tests can count what ran.
ctx.work_dir = unit.work_dir;
ctx.files = struct();
ctx.unit = unit.id;
ctx.calls = fullfile(cfg.output_dir, 'calls', [unit.id '.txt']);
ctx = seecat.util.run_step(ctx, 'step1', @step1, struct('value', cfg.value), log);
ctx = seecat.util.run_step(ctx, 'step2', @step2, struct('value', cfg.value, 'fail', ismember(unit.id, cfg.fail_units)), log);
result = struct('value', cfg.value, 'label', ['L' unit.id]);
end

function ctx = step1(ctx, opt, ~)
record(ctx, 'step1');
ctx.files.a = fullfile(ctx.work_dir, 'a.txt');
writeFile(ctx.files.a, opt.value);
end

function ctx = step2(ctx, opt, ~)
record(ctx, 'step2');
if opt.fail
    error('demo:fail', 'Unit %s failed on purpose.', ctx.unit);
end
ctx.files.b = fullfile(ctx.work_dir, 'b.txt');
writeFile(ctx.files.b, opt.value);
end

function record(ctx, step)
d = fileparts(ctx.calls);
if ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(ctx.calls, 'a');
fprintf(fid, '%s\n', step);
fclose(fid);
end

function writeFile(f, v)
if ~exist(fileparts(f), 'dir')
    mkdir(fileparts(f));
end
fid = fopen(f, 'w');
fprintf(fid, '%g', v);
fclose(fid);
end
