function varargout = SeeCAT_FuncConnect(varargin)
% SEECAT_FUNCCONNECT MATLAB code for SeeCAT_FuncConnect.fig
%      SEECAT_FUNCCONNECT, by itself, creates a new SEECAT_FUNCCONNECT or raises the existing
%      singleton*.
%
%      H = SEECAT_FUNCCONNECT returns the handle to a new SEECAT_FUNCCONNECT or the handle to
%      the existing singleton*.
%
%      SEECAT_FUNCCONNECT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SEECAT_FUNCCONNECT.M with the given input arguments.
%
%      SEECAT_FUNCCONNECT('Property','Value',...) creates a new SEECAT_FUNCCONNECT or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before SeeCAT_FuncConnect_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to SeeCAT_FuncConnect_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help SeeCAT_FuncConnect

% Last Modified by GUIDE v2.5 05-Jul-2017 14:49:19

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @SeeCAT_FuncConnect_OpeningFcn, ...
    'gui_OutputFcn',  @SeeCAT_FuncConnect_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before SeeCAT_FuncConnect is made visible.
function SeeCAT_FuncConnect_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to SeeCAT_FuncConnect (see VARARGIN)

% Choose default command line output for SeeCAT_FuncConnect
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

movegui(hObject,'center');
% UIWAIT makes SeeCAT_FuncConnect wait for user response (see UIRESUME)
% uiwait(handles.SeeCAT_FC_figure);
set(handles.WorkDir_edit,'String',pwd);
ProgramPath = fileparts(which('SeeCAT.m'));
if ispc
    filesep = '\';
else
    filesep = '/';
end
set(handles.Mask_edit,'String',[ProgramPath,filesep,'templates',filesep,'tpl-IXI549Space_res-3_label-GM_mask.nii']);



% --- Outputs from this function are returned to the command line.
function varargout = SeeCAT_FuncConnect_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function WorkDir_edit_Callback(hObject, eventdata, handles)
% hObject    handle to WorkDir_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of WorkDir_edit as text
%        str2double(get(hObject,'String')) returns contents of WorkDir_edit as a double


% --- Executes during object creation, after setting all properties.
function WorkDir_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to WorkDir_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in WorkDir_pushbutton.
function WorkDir_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to WorkDir_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
folder_name = uigetdir(pwd,'Select Working Directory');
if isequal(folder_name,0)
    return;
else
    set(handles.WorkDir_edit,'String',folder_name);
end



function StartFolder_edit_Callback(hObject, eventdata, handles)
% hObject    handle to StartFolder_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of StartFolder_edit as text
%        str2double(get(hObject,'String')) returns contents of StartFolder_edit as a double


% --- Executes during object creation, after setting all properties.
function StartFolder_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to StartFolder_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in Seed_listbox.
function Seed_listbox_Callback(hObject, eventdata, handles)
% hObject    handle to Seed_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns Seed_listbox contents as cell array
%        contents{get(hObject,'Value')} returns selected item from Seed_listbox
persistent chk
if isempty(chk)
    chk = 1;
    pause(0.5);
    if chk == 1
        chk = [];
    end
else
    chk = [];
    list_string = get(hObject,'String');
    list_pos = get(hObject,'Value');
    list_string(list_pos) = [];
    if isempty(list_string)
        list_string{1} = [];
    end
    if list_pos > length(list_string)
        set(hObject,'Value',list_pos - 1);
    end
    set(hObject,'String',list_string);
end

% --- Executes during object creation, after setting all properties.
function Seed_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Seed_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in AddSpheres_pushbutton.
function AddSpheres_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to AddSpheres_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
SphereMat = AddSpheres;
SphereList = num2cell(SphereMat,2);
SeedList = get(handles.Seed_listbox,'String');
nSeed = length(SeedList);
if nSeed == 1 && isempty(SeedList{1})
    nSeed = 0;
end
for i = nSeed+1:nSeed+length(SphereList)
    SeedList{i,1} = ['Sphere: ',num2str(SphereList{i-nSeed})];
end
set(handles.Seed_listbox,'String',SeedList);



% --- Executes on button press in AddClusters_pushbutton.
function AddClusters_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to AddClusters_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[Name, Path] = uigetfile({'*.img;*.nii;*.nii.gz','Brain Image Files (*.img;*.nii;*.nii.gz)';'*.*', 'All Files (*.*)';},...
    'Pick the Masks for ROI', 'MultiSelect','on');
if isnumeric(Name)
    return
end
SeedList = get(handles.Seed_listbox,'String');
nSeed = length(SeedList);
if nSeed == 1 && isempty(SeedList{1})
    nSeed = 0;
end
if ischar(Name)
    Name={Name};
end
for i = nSeed+1:nSeed+length(Name)
    SeedList{i,1} = ['Mask: ',Path,Name{i-nSeed}];
end
set(handles.Seed_listbox,'String',SeedList);




function Mask_edit_Callback(hObject, eventdata, handles)
% hObject    handle to Mask_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Mask_edit as text
%        str2double(get(hObject,'String')) returns contents of Mask_edit as a double


% --- Executes during object creation, after setting all properties.
function Mask_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Mask_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Mask_pushbutton.
function Mask_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Mask_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[Name, Path] = uigetfile({'*.img;*.nii;*.nii.gz','Brain Image Files (*.img;*.nii;*.nii.gz)';'*.*', 'All Files (*.*)';},...
    'Pick the Masks for Calculation');
if isnumeric(Name)
    return
end
set(handles.Mask_edit,'String',[Path,Name]);


function edit4_Callback(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit4 as text
%        str2double(get(hObject,'String')) returns contents of edit4 as a double


% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in Run_pushbutton.
function Run_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Run_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'Enable','off');
set(hObject,'String','running...');
tic
if get(handles.Parallel_checkbox,'Value') == 1
    seecat.util.start_pool;
end
if ispc
    filesep = '\';
else
    filesep = '/';
end
WorkDir = get(handles.WorkDir_edit,'String');
StartFolder = get(handles.StartFolder_edit,'String');
SeedList = get(handles.Seed_listbox,'String');
nSeed = length(SeedList);
MaskName = get(handles.Mask_edit,'String');

Log_Text = datestr(now);
Log_Text = sprintf('%s\n%s\n',Log_Text,['Working directory: ',WorkDir]);
Log_Text = sprintf('%s%s\n\n',Log_Text,['Start folder: ',StartFolder]);
Log_Text = sprintf('%s%s\n',Log_Text,'Seed list: ');
for i = 1:nSeed
    Log_Text = sprintf('%s%s\n',Log_Text,['  ',SeedList{i}]);
end
Log_Text = sprintf('%s%s\n',Log_Text,'');
Log_Text = sprintf('%s%s\n',Log_Text,['Calculation mask: ',MaskName]);
fid = fopen([WorkDir,filesep,'Log_FC_',datestr(now,'yyyymmddHHMMSS'),'.txt'],'at+');
fprintf(fid,'%s',Log_Text);
fclose(fid);


fprintf('Calculating Functional Connectivity Started.\n');

Sublist = sc_list_subjects([WorkDir,filesep,StartFolder]);
nSub = numel(Sublist);
if nSub == 0
    errordlg(['No subject folders found in ',WorkDir,filesep,StartFolder]);
    set(hObject,'Enable','on');
    set(hObject,'String','RUN');
    return
end
DataFiles = cellfun(@(s) FindSubjectImage([WorkDir,filesep,StartFolder,filesep,s]), Sublist, 'UniformOutput', false);

% All maps are computed on the voxel grid of the functional data; the
% calculation mask and mask-type seeds are resampled to it if needed.
hdr_ref = spm_vol(DataFiles{1});
hdr_ref = hdr_ref(1);
vol_mask = seecat.io.resample(MaskName, hdr_ref);
[gx,gy,gz] = ndgrid(1:hdr_ref.dim(1),1:hdr_ref.dim(2),1:hdr_ref.dim(3));
XYZ = hdr_ref.mat(1:3,:) * [gx(:)';gy(:)';gz(:)';ones(1,numel(gx))];
clear gx gy gz

seed_ind = cell(nSeed,1);
for i = 1:nSeed
    switch SeedList{i}(1)
        case 'S'
            CoordMat = str2num(SeedList{i}(8:end));
            distance = sqrt(sum((XYZ - CoordMat(1:3)').^2,1));
            seed_ind{i} = distance<=CoordMat(4);
        case 'M'
            seed_ind{i} = reshape(seecat.io.resample(SeedList{i}(7:end), hdr_ref)>0,1,[]);
    end
    if ~any(seed_ind{i})
        errordlg(sprintf('Seed %d contains no voxels on the data grid: %s', i, SeedList{i}));
        set(hObject,'Enable','on');
        set(hObject,'String','RUN');
        return
    end
end

mask_ind = reshape(vol_mask>0,1,[]);
OutDir = [WorkDir,filesep,'Results',filesep,'FC_',StartFolder];
for j = 1:nSeed
    SeedTag = sprintf('%02d',j);
    if ~exist([OutDir,filesep,'FC_Seed',SeedTag],'dir'), mkdir([OutDir,filesep,'FC_Seed',SeedTag]); end
    if ~exist([OutDir,filesep,'zFC_Seed',SeedTag],'dir'), mkdir([OutDir,filesep,'zFC_Seed',SeedTag]); end
end
if get(handles.Parallel_checkbox,'Value') == 1
    nWorker = Inf;
else
    nWorker = 0;
end
parfor (i = 1:nSub, nWorker)
    sc_seed_fc_subject(DataFiles{i}, Sublist{i}, hdr_ref, mask_ind, seed_ind, OutDir);
end
cd(WorkDir);
fprintf('Calculating Functional Connectivity Finished.\n');
toc
set(hObject,'Enable','on');
set(hObject,'String','RUN');


function z = FisherTrans(r)
z = 0.5*log((1+r)./(1-r));


function Filename = FindSubjectImage(SubDir)
% The single 4D NIfTI image in a subject folder
f = dir([SubDir,filesep,'*.nii']);
f = f(~startsWith({f.name},'.'));
if numel(f) ~= 1
    error('SeeCAT:FC:input','Expected exactly one 4D .nii image in %s, found %d.',SubDir,numel(f));
end
Filename = [SubDir,filesep,f.name];


% --- Executes on button press in Quit_pushbutton.
function Quit_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Quit_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
delete(handles.SeeCAT_FC_figure);


% --- Executes on button press in Parallel_checkbox.
function Parallel_checkbox_Callback(hObject, eventdata, handles)
% hObject    handle to Parallel_checkbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Parallel_checkbox
