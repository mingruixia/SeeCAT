function r = matlab_screen()
%MATLAB_SCREEN The screen the MATLAB desktop is on, as [left bottom width height].
%   R = seecat.gui.matlab_screen() returns the row of
%   get(groot, 'MonitorPositions') for the screen that shows the MATLAB
%   desktop, so a new window can open there. It tries, in order:
%     - the Java desktop (MATLAB releases before the new desktop);
%     - on Windows, the window of the MATLAB process that started this one
%       (the new desktop draws its window in that process);
%     - the screen under the mouse pointer.
%   With none of these, or with one screen, it returns the primary screen.

mons = get(groot, 'MonitorPositions');
r = mons(1, :);
if size(mons, 1) < 2
    return
end
k = [];
try
    k = javaDesktop(mons);
catch
end
if isempty(k) && ispc && desktop('-inuse')
    try
        k = windowsDesktop(mons);
    catch
    end
end
if isempty(k)
    k = containing(mons, get(groot, 'PointerLocation'));
end
if ~isempty(k)
    r = mons(k, :);
end
end

function k = javaDesktop(mons)
% The Java desktop's main frame; Java measures y down from the top of the
% primary screen, MATLAB up from its bottom.
% Asked on the new desktop (R2025a on), the Java desktop takes seconds to
% answer that it has no frame, so it is asked only on older releases.
k = [];
if ~usejava('desktop') || ~olderThan2025a()
    return
end
try
    if feature('webui')         % the new desktop, in a beta before R2025a
        return
    end
catch
end
fr = com.mathworks.mde.desk.MLDesktop.getInstance.getMainFrame; %#ok<JAPIMATHWORKS>
if isempty(fr) || ~isjava(fr) || ~fr.isShowing
    return
end
l = fr.getLocationOnScreen;
s = fr.getSize;
c = [l.x + s.width / 2, mons(1, 2) + mons(1, 4) - (l.y + s.height / 2)];
k = containing(mons, c);
end

function k = windowsDesktop(mons)
% The parent of this MATLAB process owns the desktop window. Windows gives
% its screen in device pixels and MATLAB its screens in scaled pixels, so the
% screens are matched by their order (left to right, then top to bottom).
% With a single MATLAB window it is this one; the lookup of the parent
% process (WMI) is slower, so it is used only with several.
k = [];
ps = System.Diagnostics.Process.GetProcessesByName('MATLAB');
h = [];
n = 0;
for i = 1:ps.Length
    if ps(i).MainWindowHandle.ToInt64() ~= 0
        h = ps(i).MainWindowHandle;
        n = n + 1;
    end
end
if n == 0
    return
elseif n > 1
    NET.addAssembly('System.Management');
    q = System.Management.ManagementObjectSearcher(sprintf( ...
        'SELECT ParentProcessId FROM Win32_Process WHERE ProcessId = %d', feature('getpid')));
    it = q.Get().GetEnumerator();
    if ~it.MoveNext()
        return
    end
    parent = System.Diagnostics.Process.GetProcessById(double(it.Current.GetPropertyValue('ParentProcessId')));
    h = parent.MainWindowHandle;
    if h.ToInt64() == 0
        return
    end
end
NET.addAssembly('System.Windows.Forms');
scr = System.Windows.Forms.Screen.AllScreens;
if scr.Length ~= size(mons, 1)
    return
end
on = System.Windows.Forms.Screen.FromHandle(h).DeviceName;
b = zeros(scr.Length, 2);
at = 0;
for i = 1:scr.Length
    b(i, :) = [scr(i).Bounds.X, scr(i).Bounds.Y];
    if strcmp(char(scr(i).DeviceName), char(on))
        at = i;
    end
end
if at == 0
    return
end
[~, net] = sortrows(b);
[~, mat] = sortrows([mons(:, 1), -(mons(:, 2) + mons(:, 4))]);
k = mat(net == at);
end

function tf = olderThan2025a()
if exist('isMATLABReleaseOlderThan', 'file')
    tf = isMATLABReleaseOlderThan('R2025a');
else
    tf = verLessThan('matlab', '25.1'); %#ok<VERLESSMATLAB>
end
end

function k = containing(mons, p)
k = find(p(1) >= mons(:, 1) & p(1) < mons(:, 1) + mons(:, 3) & ...
    p(2) >= mons(:, 2) & p(2) < mons(:, 2) + mons(:, 4), 1);
end
