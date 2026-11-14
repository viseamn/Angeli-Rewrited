if not LPH_OBFUSCATED then
	LPH_ENCFUNC = function(callback)
		return callback
	end
	LPH_NO_VIRTUALIZE = function(...)
		return ...
	end
	LPH_NO_UPVALUES = function(...)
		return ...
	end
	LPH_JIT_MAX = function(...)
		return ...
	end
	LPH_JIT = function(...)
		return ...
	end
end

local _cloneref = type(cloneref) == 'function' and cloneref or function(value)
	return value
end

local user_input_service = _cloneref(game:GetService('UserInputService'))
local tween_service = _cloneref(game:GetService('TweenService'))
local text_service = _cloneref(game:GetService('TextService'))
local http_service = _cloneref(game:GetService('HttpService'))
local core_gui = _cloneref(game:GetService('CoreGui'))
local debris = _cloneref(game:GetService('Debris'))

local _new_instance = Instance.new
local _new_tween_info = TweenInfo.new
local _new_udim = UDim.new
local _new_udim2 = UDim2.new
local _udim2_from_offset = UDim2.fromOffset
local _new_vector2 = Vector2.new

local _clamp = math.clamp
local _floor = math.floor
local _max = math.max
local _min = math.min

local _clear = table.clear
local _find = table.find
local _insert = table.insert
local _sort = table.sort

local _defer = task.defer
local _delay = task.delay
local _create_tween = tween_service.Create

local _pairs = pairs
local _pcall = pcall
local _tostring = tostring
local _type = type

local FONT = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)

local WINDOW_WIDTH = 640
local WINDOW_HEIGHT = 460
local SIDEBAR_WIDTH = 160
local ROW_HEIGHT = 24
local COLUMN_MARGIN = 10
local COLUMN_GAP = 12
local COLUMN_WIDTH = (WINDOW_WIDTH - SIDEBAR_WIDTH - COLUMN_MARGIN * 2 - COLUMN_GAP) / 2

local NOTIFY_MOTION = {
	['bottom-right'] = { enter = 1, exit = 1 },
	['bottom-left'] = { enter = 1, exit = -1 },
	['top-right'] = { enter = -1, exit = 1 },
}

local NOTIFY_ANCHORS = {
	['top-right'] = { horizontal = Enum.HorizontalAlignment.Right, vertical = Enum.VerticalAlignment.Top },
	['bottom-left'] = { horizontal = Enum.HorizontalAlignment.Left, vertical = Enum.VerticalAlignment.Bottom },
	['bottom-right'] = { horizontal = Enum.HorizontalAlignment.Right, vertical = Enum.VerticalAlignment.Bottom },
}

local theme
local save_manager

local column_base = setmetatable({}, { __mode = 'k' })
local connections = {}

local function watch(signal, callback)
	local connection = signal:Connect(callback)
	_insert(connections, connection)
	return connection
end

local function normalize_name(value)
	local text = string.lower(_tostring(value or ''))
	text = string.gsub(text, '^%s+', '')
	return string.gsub(text, '%s+$', '')
end

local function trim(value)
	local text = _tostring(value or '')
	text = string.gsub(text, '^%s+', '')
	return string.gsub(text, '%s+$', '')
end

local function shallow_copy(source)
	local copy = {}
	for index, value in source or {} do
		copy[index] = value
	end
	return copy
end

local create_new = LPH_NO_VIRTUALIZE(function(class_name, properties)
	local instance = _new_instance(class_name)
	for property, value in properties do
		if property ~= 'Parent' then
			instance[property] = value
		end
	end
	instance.Parent = properties.Parent
	return instance
end)

local create_round = LPH_NO_VIRTUALIZE(function(instance, radius)
	return create_new('UICorner', {
		CornerRadius = _new_udim(0, radius),
		Parent = instance,
	})
end)

local create_pill = LPH_NO_VIRTUALIZE(function(instance)
	return create_new('UICorner', {
		CornerRadius = _new_udim(1, 0),
		Parent = instance,
	})
end)

local create_outline = LPH_NO_VIRTUALIZE(function(instance, refresh)
	local stroke = create_new('UIStroke', {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = instance,
	})
	theme.paint(stroke, 'Color', 'stroke')
	if refresh then
		instance:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
			stroke.Enabled = false
			stroke.Enabled = true
		end)
	end
	return stroke
end)

local create_list = LPH_NO_VIRTUALIZE(function(instance, gap)
	return create_new('UIListLayout', {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = _new_udim(0, gap or 0),
		Parent = instance,
	})
end)

local create_padding = LPH_NO_VIRTUALIZE(function(instance, top, bottom, left, right)
	return create_new('UIPadding', {
		PaddingTop = _new_udim(0, top),
		PaddingBottom = _new_udim(0, bottom),
		PaddingLeft = _new_udim(0, left),
		PaddingRight = _new_udim(0, right),
		Parent = instance,
	})
end)

local create_label = LPH_NO_VIRTUALIZE(function(properties)
	local role = properties.TextRole or 'text_dim'
	properties.TextRole = nil
	properties.BackgroundTransparency = 1
	properties.FontFace = properties.FontFace or FONT
	properties.BorderSizePixel = 0
	properties.TextColor3 = properties.TextColor3 or theme.color(role)
	local label = create_new('TextLabel', properties)
	theme.paint(label, 'TextColor3', role)
	return label
end)

local create_divider = LPH_NO_VIRTUALIZE(function(parent, position, size)
	local divider = create_new('Frame', {
		Position = position,
		Size = size,
		BorderSizePixel = 0,
		Parent = parent,
	})
	theme.paint(divider, 'BackgroundColor3', 'stroke')
	return divider
end)

local create_scroller = LPH_NO_VIRTUALIZE(function(parent, position, size)
	local frame = create_new('ScrollingFrame', {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		CanvasSize = _new_udim2(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	})
	return frame
end)

library = {
	_flags = {},
	_controls = {},
	_dropdowns = {},
	_custom_themes = {},
	_current = nil,
}

library.__index = library

function library.attach(theme_module, save_module)
	theme = theme_module
	save_manager = save_module
end

local interface_parent = (gethui and gethui()) or core_gui

for _, name in { '_angeli', '_angeli_notify' } do
	local previous = interface_parent:FindFirstChild(name)

	if previous then
		debris:AddItem(previous, 0)
	end
end

function library:_persist_state()
	save_manager.write_state({
		profile = save_manager._active,
		theme = theme.current(),
		autosave = save_manager._autosave,
		notify = library._current and library._current._notify_position or nil,
		themes = library._custom_themes,
	})
end

function library:_save()
	if not save_manager._autosave then
		save_manager._dirty = true
		return
	end
	save_manager.save(save_manager._active, true)
	self:pulse_saved()
end

function library:_bind(flag, sync)
	if _type(flag) ~= 'string' then
		return
	end
	_insert(self._controls, {
		flag = flag,
		sync = sync,
	})
end

function library:_sync_controls()
	for _, control in self._controls do
		local value = self._flags[control.flag]
		if value ~= nil then
			_pcall(control.sync, value)
		end
	end
end

function library:_apply_flags(values)
	_clear(self._flags)
	for key, value in _pairs(values) do
		self._flags[key] = value
	end
	self:_sync_controls()
end

function library:close_all_dropdowns()
	for _, dropdown in self._dropdowns do
		if dropdown._open then
			dropdown:unfold(false)
		end
	end
end

local function resolve_runtime(self)
	if self ~= library and _type(self) == 'table' and self._tabs then
		return self
	end
	return library._current
end

library._new = function(runtime_type)
	local is_mobile = user_input_service.TouchEnabled
		or not (user_input_service.KeyboardEnabled and user_input_service.MouseEnabled)
	local state = save_manager.state()

	local self = setmetatable({
		_tabs = {},
		_tab_registry = {},
		_categories = {},
		_category_registry = {},
		_active_tab = nil,
		_layout_order = 0,
		_category_order = 0,
		_type = runtime_type,
		_flags = library._flags,
		_controls = library._controls,
		_dropdowns = {},
		_keybind_entries = {},
		_keybind_visible = false,
		_is_mobile = is_mobile,
		_ui_scale = 1,
		_label_size = is_mobile and 15 or 14,
		_small_size = is_mobile and 11 or 10,
		_ui_open = true,
		_dragging = false,
	}, library)

	library._current = self

	if _type(state.autosave) == 'boolean' then
		save_manager._autosave = state.autosave
	end

	if _type(state.profile) == 'string' and state.profile ~= '' then
		save_manager._active = state.profile
	end

	if _type(state.notify) == 'string' and NOTIFY_ANCHORS[state.notify] then
		self._notify_position = state.notify
	end

	self:_init()
	self:_init_keybinds()

	self:set_notify_position(self._notify_position, true)

	if _type(state.themes) == 'table' then
		for name, palette in _pairs(state.themes) do
			local decoded = {}

			for role, hex in _pairs(palette) do
				local color = theme.from_hex(hex)

				if color then
					decoded[role] = color
				end
			end

			if next(decoded) then
				theme.register(name, decoded)
				library._custom_themes[name] = palette
			end
		end
	end

	if _type(state.theme) == 'string' and theme._palettes[state.theme] then
		theme.apply(state.theme, false)
	end

	return self
end

function library:_init()
	if _type(set_thread_identity) == 'function' then
		_pcall(set_thread_identity, 6)
	end

	local gui = create_new('ScreenGui', {
		Name = '_angeli',
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = interface_parent,
	})

	if syn and syn.protect_gui then
		syn.protect_gui(gui)
	end

	self._ui = gui

	local container = create_new('Frame', {
		AnchorPoint = _new_vector2(0.5, 0.5),
		Position = _new_udim2(0.5, 0, 0.5, 0),
		Size = _new_udim2(0, 0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = gui,
	})

	theme.paint(container, 'BackgroundColor3', 'bg')
	create_round(container, 8)
	create_outline(container)

	_create_tween(tween_service, container, _new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = _udim2_from_offset(WINDOW_WIDTH, WINDOW_HEIGHT),
	}):Play()

	local scale_object = create_new('UIScale', {
		Parent = container,
	})

	self._scale_object = scale_object

	local notify_gui = create_new('ScreenGui', {
		Name = '_angeli_notify',
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = interface_parent,
	})

	if syn and syn.protect_gui then
		syn.protect_gui(notify_gui)
	end

	self._notify_gui = notify_gui

	local notification_holder = create_new('Frame', {
		Name = '_notifications',
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 1, 0),
		BorderSizePixel = 0,
		ZIndex = 199,
		Parent = notify_gui,
	})

	create_padding(notification_holder, 8, 8, 12, 12)

	local notification_layout = create_new('UIListLayout', {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = _new_udim(0, 8),
		Parent = notification_holder,
	})

	self._notification_holder = notification_holder
	self._notification_layout = notification_layout
	self._notification_order = 0
	self._notifications = {}
	self._notify_position = 'bottom-right' 

	local sidebar = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(0, SIDEBAR_WIDTH, 1, 0),
		Parent = container,
	})

	create_divider(sidebar, _new_udim2(1, -1, 0, 48), _new_udim2(0, 1, 1, -48))

	local logo_area = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 0, 48),
		Parent = sidebar,
	})

	create_label({
		Position = _new_udim2(0, 20, 0, 0),
		Size = _new_udim2(1, -30, 1, 0),
		Text = 'Angeli',
		TextRole = 'text',
		TextSize = self._is_mobile and 18 or 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = logo_area,
	})

	local saved_dot = create_new('Frame', {
		AnchorPoint = _new_vector2(1, 0.5),
		Position = _new_udim2(1, -14, 0.5, 0),
		Size = _new_udim2(0, 5, 0, 5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = logo_area,
	})

	theme.paint(saved_dot, 'BackgroundColor3', 'accent')
	create_pill(saved_dot)

	self._saved_dot = saved_dot

	create_divider(logo_area, _new_udim2(0, 0, 1, -1), _new_udim2(1, 0, 0, 1))

	local highlight = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(0, 0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = sidebar,
	})

	theme.paint(highlight, 'BackgroundColor3', 'surface_alt')
	create_round(highlight, 6)

	self._highlight = highlight

	local pin = create_new('Frame', {
		Position = _new_udim2(0, 4, 0, 0),
		Size = _new_udim2(0, 2, 0, 16),
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = sidebar,
	})

	theme.paint(pin, 'BackgroundColor3', 'accent')
	create_pill(pin)

	local tabs_container = create_scroller(sidebar, _new_udim2(0, 0, 0, 48), _new_udim2(1, 0, 1, -48))
	create_padding(tabs_container, 12, 16, 10, 10)
	create_list(tabs_container, 6)

	local content = create_new('Frame', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, SIDEBAR_WIDTH, 0, 0),
		Size = _new_udim2(0, WINDOW_WIDTH - SIDEBAR_WIDTH, 1, 0),
		Parent = container,
	})

	local topbar = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 0, 48),
		ZIndex = 5,
		Parent = content,
	})

	local topbar_divider = create_divider(topbar, _new_udim2(0, 0, 1, -1), _new_udim2(1, 0, 0, 1))
	topbar_divider.ZIndex = 6

	local sections_viewport = create_new('Frame', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, 0, 0, 48),
		Size = _new_udim2(1, 0, 1, -48),
		ClipsDescendants = true,
		Parent = content,
	})

	local sections = create_new('Folder', {
		Parent = sections_viewport,
	})

	local mobile_toggle_gui = create_new('ScreenGui', {
		Name = '_angeli_toggle',
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = gui,
	})

	local mobile_toggle = create_new('TextButton', {
		AnchorPoint = _new_vector2(0.5, 0),
		Position = _new_udim2(0.5, 0, 0, 12),
		Size = _new_udim2(0, 40, 0, 40),
		Text = '',
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible = self._is_mobile,
		ZIndex = 100,
		Parent = mobile_toggle_gui,
	})

	theme.paint(mobile_toggle, 'BackgroundColor3', 'surface')
	create_round(mobile_toggle, 8)
	create_outline(mobile_toggle)

	local toggle_icon = create_new('ImageLabel', {
		BackgroundTransparency = 1,
		AnchorPoint = _new_vector2(0.5, 0.5),
		Position = _new_udim2(0.5, 0, 0.5, 0),
		Size = _new_udim2(0, 20, 0, 20),
		Image = 'rbxassetid://10709812159',
		ZIndex = 101,
		Parent = mobile_toggle,
	})

	theme.paint(toggle_icon, 'ImageColor3', 'text')

	local apply_scale = LPH_NO_VIRTUALIZE(function()
		if self._is_mobile then
			local viewport = workspace.CurrentCamera.ViewportSize
			if self._ui.AbsoluteSize.Y > 0 then
				viewport = self._ui.AbsoluteSize
			end
			self._ui_scale = _clamp(
				_min((viewport.X / 1400) * 1.4375, (viewport.X * 0.95) / WINDOW_WIDTH, (viewport.Y * 0.95) / WINDOW_HEIGHT),
				0.503125,
				1.4375
			)
		else
			self._ui_scale = 1
		end

		scale_object.Scale = self._ui_scale

		if self._keybind_scale then
			self._keybind_scale.Scale = self._ui_scale
		end

		_defer(function()
			self:_move_pin()
			self:_move_highlight(true)
		end)
	end)

	self._apply_scale = apply_scale
	apply_scale()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
			_defer(apply_scale)
		end)
	end

	local drag_connection = nil
	container.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		self._dragging = true
		self._drag_start = input.Position
		self._drag_origin = container.Position

		self:close_all_dropdowns()

		if drag_connection then
			drag_connection:Disconnect()
		end

		drag_connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				self._dragging = false
				if drag_connection then
					drag_connection:Disconnect()
					drag_connection = nil
				end
			end
		end)
	end)

	watch(user_input_service.InputChanged, function(input)
		if not self._dragging then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local delta = (input.Position - self._drag_start) / self._ui_scale

		_create_tween(tween_service, container, _new_tween_info(0.2), {
			Position = _new_udim2(
				self._drag_origin.X.Scale,
				self._drag_origin.X.Offset + delta.X,
				self._drag_origin.Y.Scale,
				self._drag_origin.Y.Offset + delta.Y
			),
		}):Play()
	end)

	watch(user_input_service.InputBegan, function(input, processed)
		if processed then
			return
		end

		local key_name = self._flags.minimize_key
		local minimize_key = Enum.KeyCode.Insert

		if _type(key_name) == 'string' then
			local ok, resolved = _pcall(function()
				return Enum.KeyCode[key_name]
			end)
			if ok and resolved then
				minimize_key = resolved
			end
		end

		if input.KeyCode == minimize_key then
			self:set_open(not self._ui_open)
		end
	end)

	mobile_toggle.MouseButton1Click:Connect(function()
		self:set_open(not self._ui_open)
	end)

	self._container = container
	self._sidebar = sidebar
	self._pin = pin
	self._tabs_container = tabs_container
	self._sections = sections
	self._main_content = content
	self._topbar = topbar
end

function library:_move_pin()
	if not self._active_tab or not self._pin then
		return
	end

	local button = self._active_tab._button
	local target = _new_udim2(
		0,
		4,
		0,
		(button.AbsolutePosition.Y - self._sidebar.AbsolutePosition.Y + button.AbsoluteSize.Y / 2) / self._ui_scale - 8
	)

	_create_tween(
		tween_service,
		self._pin,
		_new_tween_info(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			Position = target,
		}
	):Play()
end

function library:_move_highlight(instant)
	if not self._highlight or not self._active_tab then
		return false
	end

	local button = self._active_tab._button
	local size = button.AbsoluteSize

	if size.Y <= 0 then
		return false
	end

	local scale = self._ui_scale
	local origin = self._sidebar.AbsolutePosition
	local target_position = _new_udim2(
		0,
		(button.AbsolutePosition.X - origin.X) / scale,
		0,
		(button.AbsolutePosition.Y - origin.Y) / scale
	)
	local target_size = _new_udim2(0, size.X / scale, 0, size.Y / scale)

	if instant then
		self._highlight.Position = target_position
		self._highlight.Size = target_size
		self._highlight.BackgroundTransparency = 0
		return true
	end

	_create_tween(
		tween_service,
		self._highlight,
		_new_tween_info(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			Position = target_position,
			Size = target_size,
			BackgroundTransparency = 0,
		}
	):Play()

	return true
end

function library:set_open(state)
	if state == self._ui_open then
		return
	end
	self._ui_open = state
	local container = self._container

	if state then
		container.Visible = true
		_create_tween(tween_service, container, _new_tween_info(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = _udim2_from_offset(WINDOW_WIDTH, WINDOW_HEIGHT),
		}):Play()
		_defer(function()
			self:_move_highlight(true)
		end)
		return
	end

	self:close_all_dropdowns()

	_create_tween(tween_service, container, _new_tween_info(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Size = _new_udim2(0, 0, 0, 0),
	}):Play()

	_delay(0.34, function()
		if not self._ui_open then
			container.Visible = false
		end
	end)
end

function library:create_category(name)
	self._category_order += 1
	self._layout_order = 0

	local index = self._category_order
	local base_order = index * 1000

	local manager = {
		_name = name,
		_base_order = base_order,
		_count = 0,
	}

	function manager:create_tab(title, icon)
		self._count += 1
		return library.create_tab(self._runtime, title, icon, self._base_order + self._count, self._name)
	end

	manager._runtime = self

	_insert(self._categories, manager)
	local key = normalize_name(name)
	self._category_registry[key] = self._category_registry[key] or {}
	_insert(self._category_registry[key], manager)

	return manager
end

local group_methods

function library:create_tab(title, icon, order, category_name)
	local runtime = self
	local manager = {
		_title = title,
		_category = category_name,
		_groups = {},
		_registry = {},
	}

	if not order then
		runtime._layout_order += 1
		order = runtime._category_order * 1000 + runtime._layout_order
	end

	local first = #runtime._tabs == 0

	local button = create_new('TextButton', {
		Name = title,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = _new_udim2(1, 0, 0, 32),
		Text = '',
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = runtime._tabs_container,
	})

	create_round(button, 6)

	local icon_label = create_new('ImageLabel', {
		BackgroundTransparency = 1,
		AnchorPoint = _new_vector2(0, 0.5),
		Position = _new_udim2(0, 10, 0.5, 0),
		Size = _new_udim2(0, 16, 0, 16),
		Image = icon or 'rbxassetid://10709812159',
		Parent = button,
	})

	theme.paint(icon_label, 'ImageColor3', 'text_dim')

	local title_label = create_label({
		Position = _new_udim2(0, 34, 0, 0),
		Size = _new_udim2(1, -44, 1, 0),
		Text = title,
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})

	local column_width = runtime._is_mobile and (WINDOW_WIDTH - SIDEBAR_WIDTH - COLUMN_MARGIN * 2) or COLUMN_WIDTH

	local function create_column(x, width)
		local column = create_scroller(
			runtime._sections,
			_new_udim2(0, x - 2, 0, 0),
			_new_udim2(0, width + 4, 1, 0)
		)
		create_padding(column, 12, 16, 2, 2)
		create_list(column, 12)
		column.Visible = false
		column_base[column] = x - 2
		return column
	end

	local left = create_column(COLUMN_MARGIN, column_width)
	local right = runtime._is_mobile and left or create_column(COLUMN_MARGIN + COLUMN_WIDTH + COLUMN_GAP, column_width)

	local data = {
		_button = button,
		_icon = icon_label,
		_label = title_label,
		_left = left,
		_right = right,
		_active = false,
		_enabled = true,
		_title = title,
		_category = category_name,
		_manager = manager,
	}

	manager._data = data
	_insert(runtime._tabs, data)
	data._index = #runtime._tabs

	if first then
		runtime._active_tab = data
		runtime:update_tabs(data)
		runtime:update_sections(left, right, 1)
	end

	button.MouseButton1Click:Connect(function()
		if not data._enabled then
			return
		end

		local direction = 1
		if runtime._active_tab and data._index < runtime._active_tab._index then
			direction = -1
		end

		runtime._active_tab = data
		runtime:update_tabs(data)
		runtime:update_sections(left, right, direction)
	end)

	button.MouseEnter:Connect(function()
		if data._active then
			return
		end

		button.BackgroundColor3 = theme.color('surface')
		_create_tween(tween_service, button, _new_tween_info(0.2), {
			BackgroundTransparency = 0.35,
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		if data._active then
			return
		end

		_create_tween(tween_service, button, _new_tween_info(0.2), {
			BackgroundTransparency = 1,
		}):Play()
	end)

	function manager:set_enabled(state)
		data._enabled = state == true
		button.Active = data._enabled
		button.Selectable = data._enabled
		icon_label.ImageTransparency = data._enabled and 0 or 0.65
		title_label.TextTransparency = data._enabled and 0 or 0.65

		if not data._enabled and runtime._active_tab == data then
			for _, candidate in runtime._tabs do
				if candidate ~= data and candidate._enabled then
					runtime._active_tab = candidate
					runtime:update_tabs(candidate)
					runtime:update_sections(candidate._left, candidate._right, 1)
					break
				end
			end
		end
	end

	function manager:is_enabled()
		return data._enabled
	end

	function manager:create_group(title, side)
		local values = {}
		if _type(title) == 'table' then
			values = title
		else
			values.title = title
			values.side = side
		end
		values.title = values.title or 'Group'
		values.side = values.side == 'right' and 'right' or 'left'

		local group = {
			_order = 0,
			_title = values.title,
			_side = values.side,
		}

		local frame = create_new('Frame', {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = _new_udim2(1, 0, 0, 0),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = values.side == 'left' and left or right,
		})

		theme.paint(frame, 'BackgroundColor3', 'surface')
		create_round(frame, 8)
		create_outline(frame, true)
		create_padding(frame, 12, 12, 12, 12)
		create_list(frame, 10)

		create_label({
			LayoutOrder = 0,
			Size = _new_udim2(1, 0, 0, 12),
			Text = string.upper(values.title),
			TextSize = runtime._small_size + 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.2,
			Parent = frame,
		})

		group._frame = frame
		group._runtime = runtime

		local function next_order()
			group._order += 1
			return group._order
		end

		group._next_order = next_order

		setmetatable(group, { __index = group_methods })

		_insert(manager._groups, group)
		local key = normalize_name(values.title)
		manager._registry[key] = manager._registry[key] or {}
		_insert(manager._registry[key], group)

		return group
	end

	local key = normalize_name(title)
	runtime._tab_registry[key] = runtime._tab_registry[key] or {}
	_insert(runtime._tab_registry[key], manager)

	return manager
end

function library:update_tabs(tab)
	for _, data in self._tabs do
		local active = data == tab
		data._active = active

		data._button.BackgroundTransparency = 1
		theme.paint(data._label, 'TextColor3', active and 'text' or 'text_dim')
		theme.paint(data._icon, 'ImageColor3', active and 'text' or 'text_dim')
	end

	if tab then
		self._pin.BackgroundTransparency = 0
		self:_move_pin()
		self:_move_highlight()
		_defer(function()
			self:_move_pin()

			if not self._highlight_ready then
				self._highlight_ready = self:_move_highlight(true)
			end
		end)
	end
end

function library:update_sections(left, right, direction)
	local offset = direction == -1 and -16 or 16

	for _, object in self._sections:GetChildren() do
		if object ~= left and object ~= right and object.Visible then
			object.Visible = false
		end
	end

	local index = 0

	for _, column in { left, right } do
		if column then
			index += 1

			local base = column_base[column] or column.Position.X.Offset
			local delay = (index - 1) * 0.04

			if not column.Visible then
				column.Visible = true
				column.Position = _new_udim2(0, base, 0, offset)
			end

			_delay(delay, function()
				_create_tween(
					tween_service,
					column,
					_new_tween_info(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{
						Position = _new_udim2(0, base, 0, 0),
					}
				):Play()
			end)
		end
	end
end

function library:confirm(message, callback)
	local runtime = resolve_runtime(self)

	if not runtime or not runtime._ui then
		return false
	end

	local overlay = create_new('TextButton', {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 1, 0),
		Text = '',
		AutoButtonColor = false,
		ZIndex = 400,
		Parent = runtime._ui,
	})

	local card = create_new('Frame', {
		AnchorPoint = _new_vector2(0.5, 0.5),
		Position = _new_udim2(0.5, 0, 0.5, 0),
		Size = _new_udim2(0, 260, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 401,
		Parent = overlay,
	})

	theme.paint(card, 'BackgroundColor3', 'surface')
	create_round(card, 8)
	create_outline(card)

	create_label({
		Position = _new_udim2(0, 16, 0, 14),
		Size = _new_udim2(1, -32, 0, 38),
		Text = _tostring(message or 'Are you sure?'),
		TextRole = 'text',
		TextSize = runtime._label_size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 402,
		Parent = card,
	})

	local function close()
		_create_tween(tween_service, card, _new_tween_info(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Size = _new_udim2(0, 260, 0, 0),
		}):Play()

		_create_tween(tween_service, overlay, _new_tween_info(0.18), {
			BackgroundTransparency = 1,
		}):Play()

		_delay(0.2, function()
			if overlay.Parent then
				overlay:Destroy()
			end
		end)
	end

	local cancel = create_new('TextButton', {
		AnchorPoint = _new_vector2(1, 0),
		Position = _new_udim2(0.5, -6, 1, -38),
		Size = _new_udim2(0, 108, 0, 26),
		FontFace = FONT,
		Text = 'Cancel',
		TextSize = runtime._label_size,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 402,
		Parent = card,
	})

	theme.paint(cancel, 'BackgroundColor3', 'surface_alt')
	theme.paint(cancel, 'TextColor3', 'text_dim')
	create_round(cancel, 6)

	local accept = create_new('TextButton', {
		AnchorPoint = _new_vector2(0, 0),
		Position = _new_udim2(0.5, 6, 1, -38),
		Size = _new_udim2(0, 108, 0, 26),
		FontFace = FONT,
		Text = 'Confirm',
		TextSize = runtime._label_size,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 402,
		Parent = card,
	})

	theme.paint(accept, 'BackgroundColor3', 'accent')
	theme.paint(accept, 'TextColor3', 'accent_text')
	create_round(accept, 6)

	cancel.MouseButton1Click:Connect(function()
		close()
	end)

	accept.MouseButton1Click:Connect(function()
		close()

		if callback then
			local ok, err = _pcall(callback)

			if not ok then
				warn(`[Angeli] confirm callback failed: {_tostring(err)}`)
			end
		end
	end)

	_create_tween(tween_service, overlay, _new_tween_info(0.2), {
		BackgroundTransparency = 0.45,
	}):Play()

	_create_tween(tween_service, card, _new_tween_info(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = _new_udim2(0, 260, 0, 120),
	}):Play()

	return true
end

function library:pulse_saved()
	if not self._saved_dot then
		return
	end

	local dot = self._saved_dot

	dot.BackgroundTransparency = 0.1

	_create_tween(tween_service, dot, _new_tween_info(0.6, Enum.EasingStyle.Quint), {
		BackgroundTransparency = 1,
	}):Play()
end

function library:destroy()
	for _, connection in _pairs(connections) do
		_pcall(function()
			connection:Disconnect()
		end)
	end

	_clear(connections)

	for _, gui in _pairs({ self._ui, self._notify_gui }) do
		if gui then
			gui:Destroy()
		end
	end

	self._ui = nil
	self._notify_gui = nil

	if library._current == self then
		library._current = nil
	end
end

function library:save_theme(name)
	name = trim(name)

	if name == '' or not theme._current then
		return false
	end

	local palette = {}
	local encoded = {}

	for role, color in _pairs(theme._current) do
		palette[role] = color
		encoded[role] = theme.to_hex(color)
	end

	theme.register(name, palette)
	library._custom_themes[name] = encoded
	theme.apply(name, true)

	return true
end

function library:set_notify_position(position, silent)
	local preset = NOTIFY_ANCHORS[position]

	if not preset then
		return false
	end

	local runtime = resolve_runtime(self)

	if not runtime or not runtime._notification_layout then
		return false
	end

	runtime._notification_layout.HorizontalAlignment = preset.horizontal
	runtime._notification_layout.VerticalAlignment = preset.vertical
	runtime._notify_position = position

	if not silent then
		library._persist_state(runtime)
	end

	return true
end

function library:notify(message)
	local runtime = resolve_runtime(self)

	if not runtime or not runtime._notification_holder then
		return
	end

	local text = trim(string.gsub(_tostring(message or ''), '[\r\n]+', ' '))

	if text == '' then
		return
	end

	local width = runtime._is_mobile and 300 or 340
	local height = 48
	local duration = 2.6
	local motion = NOTIFY_MOTION[runtime._notify_position] or NOTIFY_MOTION['bottom-right']
	local offset = width * motion.enter

	runtime._notification_order += 1

	local slot = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = runtime._notification_order,
		Size = _new_udim2(0, width, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 200,
		Parent = runtime._notification_holder,
	})

	local card = create_new('TextButton', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, offset, 0, 0),
		Size = _new_udim2(1, 0, 1, 0),
		Text = '',
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 200,
		Parent = slot,
	})

	theme.paint(card, 'BackgroundColor3', 'surface')
	create_round(card, 6)

	local icon = create_new('Frame', {
		AnchorPoint = _new_vector2(0, 0.5),
		Position = _new_udim2(0, 14, 0.5, 0),
		Size = _new_udim2(0, 20, 0, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 201,
		Parent = card,
	})

	create_pill(icon)

	local icon_stroke = create_new('UIStroke', {
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = icon,
	})

	theme.paint(icon_stroke, 'Color', 'text')
	icon_stroke.Transparency = 1

	local icon_label = create_label({
		Size = _new_udim2(1, 0, 1, 0),
		Text = 'i',
		TextRole = 'text',
		TextSize = runtime._small_size + 3,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = 1,
		ZIndex = 202,
		Parent = icon,
	})

	local label = create_label({
		Position = _new_udim2(0, 44, 0, 0),
		Size = _new_udim2(1, -58, 1, 0),
		Text = text,
		TextRole = 'text',
		TextSize = runtime._label_size + 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 1,
		ZIndex = 201,
		Parent = card,
	})

	local bar = create_new('Frame', {
		AnchorPoint = _new_vector2(0, 1),
		Position = _new_udim2(0, 0, 1, 0),
		Size = _new_udim2(1, 0, 0, 12),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ZIndex = 203,
		Parent = card,
	})

	theme.paint(bar, 'BackgroundColor3', 'accent')
	create_round(bar, 6)

	local bar_cover = create_new('Frame', {
		Position = _new_udim2(0, 0, 1, -12),
		Size = _new_udim2(1, 0, 0, 9),
		BorderSizePixel = 0,
		ZIndex = 204,
		Parent = card,
	})

	theme.paint(bar_cover, 'BackgroundColor3', 'surface')

	local active = runtime._notifications

	_insert(active, slot)

	for index = #active, 1, -1 do
		if not active[index].Parent then
			table.remove(active, index)
		end
	end

	while #active > 4 do
		local oldest = table.remove(active, 1)

		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	_create_tween(tween_service, slot, _new_tween_info(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = _new_udim2(0, width, 0, height),
	}):Play()

	_create_tween(tween_service, card, _new_tween_info(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = _new_udim2(0, 0, 0, 0),
		BackgroundTransparency = 0,
	}):Play()

	_create_tween(tween_service, label, _new_tween_info(0.2, Enum.EasingStyle.Quint), {
		TextTransparency = 0.1,
	}):Play()

	_create_tween(tween_service, icon_label, _new_tween_info(0.2, Enum.EasingStyle.Quint), {
		TextTransparency = 0.1,
	}):Play()

	_create_tween(tween_service, icon_stroke, _new_tween_info(0.2), { Transparency = 0 }):Play()

	_create_tween(tween_service, bar, _new_tween_info(duration, Enum.EasingStyle.Linear), {
		Size = _new_udim2(0, 0, 0, 12),
		BackgroundTransparency = 0,
	}):Play()

	local closed = false

	local function dismiss()
		if closed then
			return
		end

		closed = true

		_create_tween(tween_service, slot, _new_tween_info(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Size = _new_udim2(0, width, 0, 0),
		}):Play()

		_create_tween(tween_service, card, _new_tween_info(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Position = _new_udim2(0, width * motion.exit, 0, 0),
			BackgroundTransparency = 1,
		}):Play()

		_create_tween(tween_service, label, _new_tween_info(0.2), { TextTransparency = 1 }):Play()
		_create_tween(tween_service, icon_label, _new_tween_info(0.2), { TextTransparency = 1 }):Play()
		_create_tween(tween_service, icon_stroke, _new_tween_info(0.2), { Transparency = 1 }):Play()
		_create_tween(tween_service, bar, _new_tween_info(0.2), { BackgroundTransparency = 1 }):Play()
		_create_tween(tween_service, bar_cover, _new_tween_info(0.2), { BackgroundTransparency = 1 }):Play()

		_delay(0.3, function()
			if slot.Parent then
				slot:Destroy()
			end
		end)
	end

	card.MouseButton1Click:Connect(dismiss)

	_delay(duration, dismiss)
end

function library:_init_keybinds()
	local frame = create_new('Frame', {
		Name = '_keybinds',
		Position = _new_udim2(0, 16, 0.2, 0),
		Size = _new_udim2(0, 250, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		Active = true,
		Parent = self._ui,
	})

	theme.paint(frame, 'BackgroundColor3', 'bg')
	create_round(frame, 4)
	create_outline(frame, true)
	create_list(frame)

	self._keybind_scale = create_new('UIScale', { Parent = frame })

	local header = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Size = _new_udim2(1, 0, 0, 32),
		Parent = frame,
	})

	local icon = create_new('ImageLabel', {
		BackgroundTransparency = 1,
		AnchorPoint = _new_vector2(0, 0.5),
		Position = _new_udim2(0, 12, 0.5, 0),
		Size = _new_udim2(0, 14, 0, 14),
		Image = 'rbxassetid://10723416765',
		Parent = header,
	})

	theme.paint(icon, 'ImageColor3', 'text')

	create_label({
		Size = _new_udim2(1, 0, 1, 0),
		Text = 'Keybinds',
		TextRole = 'text',
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = header,
	})

	create_divider(header, _new_udim2(0, 0, 1, -1), _new_udim2(1, 0, 0, 1))

	local content = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = _new_udim2(1, 0, 0, 0),
		Parent = frame,
	})

	create_list(content, 2)
	create_padding(content, 6, 8, 12, 12)

	self._keybind_frame = frame
	self._keybind_content = content

	local dragging = false
	local drag_start = nil
	local origin = nil

	frame.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = true
		drag_start = input.Position
		origin = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end)

	watch(user_input_service.InputChanged, function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local delta = (input.Position - drag_start) / self._ui_scale

		_create_tween(tween_service, frame, _new_tween_info(0.15), {
			Position = _new_udim2(
				origin.X.Scale,
				origin.X.Offset + delta.X,
				origin.Y.Scale,
				origin.Y.Offset + delta.Y
			),
		}):Play()
	end)
end

function library:refresh_keybinds()
	if not self._keybind_content then
		return
	end

	for _, child in self._keybind_content:GetChildren() do
		if child:IsA('Frame') then
			child:Destroy()
		end
	end

	local any = false

	for _, entry in self._keybind_entries do
		if entry.key_name and entry.key_name ~= '' then
			any = true
			local row = create_new('Frame', {
				BackgroundTransparency = 1,
				Size = _new_udim2(1, 0, 0, 24),
				Parent = self._keybind_content,
			})

			local role = self._flags[entry.flag] and 'text' or 'text_dim'

			create_label({
				Size = _new_udim2(1, -70, 1, 0),
				Text = entry.title,
				TextRole = role,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})

			create_label({
				AnchorPoint = _new_vector2(1, 0.5),
				Position = _new_udim2(1, 0, 0.5, 0),
				Size = _new_udim2(0, 66, 0, 18),
				Text = `[ {entry.key_name} ]`,
				TextRole = role,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = row,
			})
		end
	end

	self._keybind_frame.Visible = self._keybind_visible and any
end

function library:set_keybind_visible(state)
	self._keybind_visible = state == true
	self:refresh_keybinds()
end

function library:register_keybind(flag, title, key_name)
	_insert(self._keybind_entries, {
		flag = flag,
		title = title,
		key_name = key_name,
	})
	self:refresh_keybinds()
end

local function resolve_key(value)
	if _type(value) == 'string' then
		local ok, resolved = _pcall(function()
			return Enum.KeyCode[value]
		end)
		if ok and resolved then
			return resolved
		end
		return nil
	end

	if value and value.Name and value.EnumType then
		return value
	end

	return nil
end

local function create_switch(parent, order, values, runtime)
	local state = values.default == true
	local key_flag = values.keybind_flag or (values.flag and `{values.flag}_key`)
	local key = nil

	if values.keybind then
		key = resolve_key(values.keybind == true and (values.key or Enum.KeyCode.F) or values.keybind)

		if key_flag and _type(runtime._flags[key_flag]) == 'string' then
			key = resolve_key(runtime._flags[key_flag]) or key
		end
	end

	local row = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = _new_udim2(1, 0, 0, 26),
		Parent = parent,
	})

	local label = create_label({
		Size = _new_udim2(1, key and -98 or -76, 1, 0),
		Text = values.title or 'Toggle',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local track = create_new('Frame', {
		AnchorPoint = _new_vector2(1, 0.5),
		Position = _new_udim2(1, 0, 0.5, 0),
		Size = _new_udim2(0, 30, 0, 18),
		BorderSizePixel = 0,
		Parent = row,
	})

	create_pill(track)

	local inset = (18 - 12) / 2
	local off = _new_udim2(0, inset, 0.5, 0)
	local on = _new_udim2(0, 30 - 12 - inset, 0.5, 0)

	local knob = create_new('Frame', {
		AnchorPoint = _new_vector2(0, 0.5),
		Position = off,
		Size = _new_udim2(0, 12, 0, 12),
		BorderSizePixel = 0,
		Parent = track,
	})

	create_pill(knob)

	local chip = nil
	local picking = false
	local holding = false
	local mode = values.keybind_mode or 'Toggle'

	if key then
		chip = create_new('TextButton', {
			AnchorPoint = _new_vector2(1, 0.5),
			Position = _new_udim2(1, -36, 0.5, 0),
			Size = _new_udim2(0, 18, 0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = FONT,
			Text = key.Name,
			TextSize = runtime._small_size + 1,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = row,
		})

		theme.paint(chip, 'BackgroundColor3', 'surface_alt')
		theme.paint(chip, 'TextColor3', 'text')
		create_round(chip, 4)
		create_outline(chip)
		create_padding(chip, 0, 0, 5, 5)

		create_new('UISizeConstraint', {
			MinSize = _new_vector2(18, 18),
			Parent = chip,
		})
	end

	local notify_flag = values.flag and `{values.flag}_notify`
	local notify_on = notify_flag ~= nil and runtime._flags[notify_flag] == true
	local icon_right = key and -58 or -36
	local bell_parts = {}
	local gear_parts = {}

	local function icon_button(offset)
		return create_new('TextButton', {
			AnchorPoint = _new_vector2(1, 0.5),
			Position = _new_udim2(1, offset, 0.5, 0),
			Size = _new_udim2(0, 16, 0, 16),
			BackgroundTransparency = 1,
			Text = '',
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = row,
		})
	end

	local bell = icon_button(icon_right)

	_insert(bell_parts, create_new('Frame', {
		Position = _new_udim2(0, 6, 0, 1),
		Size = _new_udim2(0, 4, 0, 3),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = bell,
	}))

	create_round(bell_parts[1], 1)

	_insert(bell_parts, create_new('Frame', {
		Position = _new_udim2(0, 3, 0, 4),
		Size = _new_udim2(0, 10, 0, 8),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = bell,
	}))

	create_round(bell_parts[2], 5)

	_insert(bell_parts, create_new('Frame', {
		Position = _new_udim2(0, 6, 0, 12),
		Size = _new_udim2(0, 4, 0, 4),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = bell,
	}))

	create_pill(bell_parts[3])

	local gear = icon_button(icon_right - 18)

	_insert(gear_parts, create_new('Frame', {
		Position = _new_udim2(0, 2, 0, 2),
		Size = _new_udim2(0, 12, 0, 12),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = gear,
	}))

	create_pill(gear_parts[1])

	for _, spot in { { 7, 0 }, { 7, 14 }, { 0, 7 }, { 14, 7 } } do
		_insert(gear_parts, create_new('Frame', {
			Position = _new_udim2(0, spot[1], 0, spot[2]),
			Size = _new_udim2(0, 2, 0, 2),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = gear,
		}))
	end

	local gear_hole = create_new('Frame', {
		Position = _new_udim2(0, 5, 0, 5),
		Size = _new_udim2(0, 6, 0, 6),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = gear,
	})

	create_pill(gear_hole)
	theme.paint(gear_hole, 'BackgroundColor3', 'surface')

	local function paint_icons(hovered)
		local bell_role = notify_on and 'accent' or 'text_dim'
		local gear_role = hovered and 'text' or 'text_dim'

		for _, part in bell_parts do
			theme.paint(part, 'BackgroundColor3', bell_role)
		end

		for _, part in gear_parts do
			theme.paint(part, 'BackgroundColor3', gear_role)
		end
	end

	paint_icons(false)

	local function render(animate)
		theme.paint(track, 'BackgroundColor3', state and 'accent' or 'surface_alt')
		theme.paint(knob, 'BackgroundColor3', state and 'accent_text' or 'text_dim')
		theme.paint(label, 'TextColor3', state and 'text' or 'text_dim')

		local target = state and on or off
		if animate then
			_create_tween(tween_service, knob, _new_tween_info(0.25, Enum.EasingStyle.Quint), { Position = target }):Play()
		else
			knob.Position = target
		end
	end

	local function set_value(value, animate, silent, quiet)
		local previous = state

		state = value == true
		render(animate)

		if values.flag then
			runtime._flags[values.flag] = state
			if not silent then
				library._save(runtime)
			end
		end

		if values.callback and not quiet then
			local ok, err = _pcall(values.callback, state)
			if not ok then
				warn(`[Angeli] toggle callback failed: {_tostring(err)}`)
			end
		end

		if notify_on and not quiet then
			library:notify(`{values.title or 'Toggle'}: {state and 'On' or 'Off'}`)
		end
	end

	local function set_key(next_key)
		key = next_key

		if chip then
			chip.Text = next_key.Name
		end

		if key_flag then
			runtime._flags[key_flag] = next_key.Name
			library._save(runtime)
		end

		for _, entry in runtime._keybind_entries do
			if entry.flag == key_flag then
				entry.key_name = next_key.Name
				break
			end
		end

		library.refresh_keybinds(runtime)
	end

	local click = create_new('TextButton', {
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 1, 0),
		Text = '',
		ZIndex = 1,
		Parent = row,
	})

	click.MouseButton1Click:Connect(function()
		set_value(not state, true)
	end)

	bell.MouseButton1Click:Connect(function()
		notify_on = not notify_on

		if notify_flag then
			runtime._flags[notify_flag] = notify_on
			library._save(runtime)
		end

		paint_icons(false)
	end)

	gear.MouseEnter:Connect(function()
		paint_icons(true)
	end)

	gear.MouseLeave:Connect(function()
		paint_icons(false)
	end)

	gear.MouseButton1Click:Connect(function()
		if runtime._option_menu then
			runtime._option_menu:Destroy()
			runtime._option_menu = nil
		end

		local mouse = user_input_service:GetMouseLocation()

		local menu = create_new('Frame', {
			Position = _new_udim2(0, mouse.X, 0, mouse.Y),
			Size = _new_udim2(0, 132, 0, 56),
			BorderSizePixel = 0,
			ZIndex = 500,
			Parent = runtime._ui,
		})

		theme.paint(menu, 'BackgroundColor3', 'surface')
		create_round(menu, 6)
		create_outline(menu)
		create_padding(menu, 4, 4, 4, 4)
		create_list(menu, 0)

		runtime._option_menu = menu

		local notify_entry = create_new('TextButton', {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = _new_udim2(1, 0, 0, 24),
			FontFace = FONT,
			Text = `Notify: {notify_on and 'On' or 'Off'}`,
			TextSize = runtime._label_size,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 501,
			Parent = menu,
		})

		theme.paint(notify_entry, 'TextColor3', 'text')
		create_padding(notify_entry, 0, 0, 8, 8)

		notify_entry.MouseButton1Click:Connect(function()
			notify_on = not notify_on
			notify_entry.Text = `Notify: {notify_on and 'On' or 'Off'}`

			if notify_flag then
				runtime._flags[notify_flag] = notify_on
				library._save(runtime)
			end

			paint_icons(false)
		end)

		local reset_entry = create_new('TextButton', {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = _new_udim2(1, 0, 0, 24),
			FontFace = FONT,
			Text = 'Reset',
			TextSize = runtime._label_size,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 501,
			Parent = menu,
		})

		theme.paint(reset_entry, 'TextColor3', 'text_dim')
		create_padding(reset_entry, 0, 0, 8, 8)

		reset_entry.MouseButton1Click:Connect(function()
			set_value(values.default == true, true)
			menu:Destroy()
			runtime._option_menu = nil
		end)
	end)


	if chip then
		chip.MouseButton1Click:Connect(function()
			picking = true
			chip.Text = '...'
		end)

		chip.MouseButton2Click:Connect(function()
			if runtime._keybind_menu then
				runtime._keybind_menu:Destroy()
				runtime._keybind_menu = nil
			end

			local mouse = user_input_service:GetMouseLocation()

			local menu = create_new('Frame', {
				Position = _new_udim2(0, mouse.X, 0, mouse.Y),
				Size = _new_udim2(0, 104, 0, 3 * 24 + 8),
				BorderSizePixel = 0,
				ZIndex = 500,
				Parent = runtime._ui,
			})

			theme.paint(menu, 'BackgroundColor3', 'surface')
			create_round(menu, 6)
			create_outline(menu)
			create_padding(menu, 4, 4, 4, 4)
			create_list(menu, 0)

			runtime._keybind_menu = menu

			for index, option in { 'Toggle', 'Hold', 'Press' } do
				local entry = create_new('TextButton', {
					BackgroundTransparency = 1,
					LayoutOrder = index,
					Size = _new_udim2(1, 0, 0, 24),
					FontFace = FONT,
					Text = option,
					TextSize = runtime._label_size,
					AutoButtonColor = false,
					BorderSizePixel = 0,
					ZIndex = 501,
					Parent = menu,
				})

				theme.paint(entry, 'TextColor3', option == mode and 'text' or 'text_dim')

				entry.MouseButton1Click:Connect(function()
					mode = option
					menu:Destroy()
					runtime._keybind_menu = nil
				end)
			end
		end)

		watch(user_input_service.InputBegan, function(input, processed)
			if picking then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					picking = false
					set_key(input.KeyCode)
				end
				return
			end

			if processed or not key or input.KeyCode ~= key then
				return
			end

			if mode == 'Hold' then
				holding = true
				set_value(true, true)
			elseif mode == 'Press' then
				if values.keybind_callback then
					_pcall(values.keybind_callback)
				end
			else
				set_value(not state, true)
			end
		end)

		watch(user_input_service.InputEnded, function(input)
			if holding and input.KeyCode == key then
				holding = false
				set_value(false, true)
			end
		end)

		if key_flag and values.keybind_list ~= false then
			library.register_keybind(runtime, key_flag, values.title or 'Toggle', key.Name)
		end
	end

	render(false)

	if values.flag and runtime._flags[values.flag] ~= nil then
		state = runtime._flags[values.flag] == true
		render(false)
	end

	theme.on_apply(function()
		render(false)
	end)

	if values.flag then
		library._bind(runtime, values.flag, function(value)
			set_value(value, false, true, true)
		end)
	end


	return {
		set = set_value,
		get = function()
			return state
		end,
		get_key = function()
			return key
		end,
	}
end

local function create_slider(parent, order, values, runtime)
	local minimum = values.minimum or values.min or 0
	local maximum = values.maximum or values.max or 100
	local value = values.default or minimum

	if values.flag and _type(runtime._flags[values.flag]) == 'number' then
		value = runtime._flags[values.flag]
	end

	value = _clamp(value, minimum, maximum)

	local row = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = _new_udim2(1, 0, 0, 34),
		Parent = parent,
	})

	create_label({
		Size = _new_udim2(1, -56, 0, 16),
		Text = values.title or 'Slider',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local value_label = create_label({
		AnchorPoint = _new_vector2(1, 0),
		Position = _new_udim2(1, 0, 0, 0),
		Size = _new_udim2(0, 48, 0, 16),
		Text = _tostring(value),
		TextRole = 'text',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local track_button = create_new('TextButton', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, 0, 0, 18),
		Size = _new_udim2(1, 0, 1, -18),
		Text = '',
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = row,
	})

	create_padding(track_button, 0, 0, 6, 6)

	local track = create_new('Frame', {
		AnchorPoint = _new_vector2(0, 0.5),
		Position = _new_udim2(0, 0, 0.5, 0),
		Size = _new_udim2(1, 0, 0, 6),
		BorderSizePixel = 0,
		Parent = track_button,
	})

	theme.paint(track, 'BackgroundColor3', 'surface_alt')
	create_pill(track)

	local fill = create_new('Frame', {
		Size = _new_udim2((value - minimum) / (maximum - minimum), 0, 1, 0),
		BorderSizePixel = 0,
		Parent = track,
	})

	theme.paint(fill, 'BackgroundColor3', 'accent')
	create_pill(fill)

	local knob = create_new('Frame', {
		AnchorPoint = _new_vector2(0.5, 0.5),
		Position = _new_udim2(1, 0, 0.5, 0),
		Size = _new_udim2(0, 12, 0, 12),
		BorderSizePixel = 0,
		Parent = fill,
	})

	theme.paint(knob, 'BackgroundColor3', 'accent')
	create_pill(knob)

	local function commit(next_value, animate, silent, quiet)
		value = _clamp(next_value, minimum, maximum)
		if values.rounding then
			value = _floor(value + 0.5)
		end

		value_label.Text = _tostring(value)

		local target = (value - minimum) / (maximum - minimum)
		if animate then
			_create_tween(tween_service, fill, _new_tween_info(0.12), { Size = _new_udim2(target, 0, 1, 0) }):Play()
		else
			fill.Size = _new_udim2(target, 0, 1, 0)
		end

		if values.flag then
			runtime._flags[values.flag] = value
			if not silent then
				library._save(runtime)
			end
		end

		if values.callback and not quiet then
			local ok, err = _pcall(values.callback, value)
			if not ok then
				warn(`[Angeli] slider callback failed: {_tostring(err)}`)
			end
		end
	end

	local dragging = false

	local function from_input(input)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local ratio = _clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
		commit(minimum + (maximum - minimum) * ratio, true)
	end

	track_button.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = true
		from_input(input)
	end)

	watch(user_input_service.InputEnded, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	watch(user_input_service.InputChanged, function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		from_input(input)
	end)

	commit(value, false, true)

	if values.flag then
		library._bind(runtime, values.flag, function(next_value)
			commit(next_value, false, true, true)
		end)
	end


	return {
		set = commit,
		get = function()
			return value
		end,
	}
end

local function create_dropdown(parent, order, values, runtime)
	local multi = values.multi == true
	local selected = {}
	local current = nil
	local options = {}
	local buttons = {}
	local open = false
	local locked = false

	for _, option in values.options or {} do
		_insert(options, _tostring(option))
	end

	current = values.default or options[1]

	if values.flag and runtime._flags[values.flag] ~= nil then
		current = runtime._flags[values.flag]
	end

	if multi and _type(current) == 'table' then
		for key, value in _pairs(current) do
			if _type(key) == 'string' and value == true then
				selected[key] = true
			elseif _type(value) == 'string' then
				selected[value] = true
			end
		end
	end

	local container = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = _new_udim2(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = parent,
	})

	create_list(container, 6)

	create_label({
		LayoutOrder = 0,
		Size = _new_udim2(1, 0, 0, 16),
		Text = values.title or 'Dropdown',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = container,
	})

	local box = create_new('Frame', {
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = _new_udim2(1, 0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = container,
	})

	theme.paint(box, 'BackgroundColor3', 'surface_alt')
	create_round(box, 6)
	create_list(box)

	local header = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Size = _new_udim2(1, 0, 0, 26),
		Parent = box,
	})

	local header_label = create_label({
		Position = _new_udim2(0, 10, 0, 0),
		Size = _new_udim2(1, values.hide_icon and -20 or -32, 1, 0),
		Text = '',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	create_new('UIGradient', {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(0.9, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = header_label,
	})

	local chevron = nil

	if not values.hide_icon then
		chevron = create_new('ImageLabel', {
			BackgroundTransparency = 1,
			AnchorPoint = _new_vector2(1, 0.5),
			Position = _new_udim2(1, -10, 0.5, 0),
			Size = _new_udim2(0, 12, 0, 12),
			Image = 'rbxassetid://10734899821',
			Parent = header,
		})
		theme.paint(chevron, 'ImageColor3', 'text_dim')
	end

	local list = create_scroller(box, _new_udim2(0, 0, 0, 24), _new_udim2(1, 0, 0, 0))
	list.LayoutOrder = 1
	create_list(list)

	local dropdown = {
		_open = open,
		_locked = locked,
		_options = options,
	}

	function dropdown:get_value()
		if multi then
			local copy = {}
			for option, state in _pairs(selected) do
				if state then
					copy[option] = true
				end
			end
			return copy
		end
		return current
	end

	local function render_header()
		if multi then
			local names = {}
			for option, state in _pairs(selected) do
				if state then
					_insert(names, option)
				end
			end
			_sort(names)
			header_label.Text = #names == 0 and (values.empty_text or 'None') or table.concat(names, ', ')
			theme.paint(header_label, 'TextColor3', #names == 0 and 'text_dim' or 'text')
			return
		end

		header_label.Text = current and _tostring(current) or (values.empty_text or 'None')
		theme.paint(header_label, 'TextColor3', current and 'text' or 'text_dim')
	end

	local function refresh_labels()
		for option, button in _pairs(buttons) do
			local label = button:FindFirstChildWhichIsA('TextLabel')
			if label then
				local is_selected = multi and selected[option] or option == current
				theme.paint(label, 'TextColor3', is_selected and 'text' or 'text_dim')
				label.TextTransparency = is_selected and 0.2 or 0.5
				button.Visible = not (values.hide_selected_option and is_selected and not multi)
			end
		end
	end

	local function list_height()
		local visible = 0
		for option in _pairs(buttons) do
			if buttons[option].Visible then
				visible += 1
			end
		end
		return _min(visible * ROW_HEIGHT, 5 * ROW_HEIGHT)
	end

	local function commit(value, silent, quiet)
		if values.flag then
			runtime._flags[values.flag] = value
			if not silent then
				library._save(runtime)
			end
		end
		if values.callback and not quiet then
			local ok, err = _pcall(values.callback, value)
			if not ok then
				warn(`[Angeli] dropdown callback failed: {_tostring(err)}`)
			end
		end
	end

	local function select_option(option)
		if multi then
			selected[option] = not selected[option]
			render_header()
			refresh_labels()
			commit(dropdown:get_value())
			list.Size = _new_udim2(1, 0, 0, list_height())
			return
		end

		current = option
		render_header()
		refresh_labels()
		commit(current)
		dropdown:unfold(false)
	end

	local function add_option(option)
		option = _tostring(option)
		if _find(options, option) then
			return
		end

		_insert(options, option)

		local button = create_new('TextButton', {
			BackgroundTransparency = 1,
			LayoutOrder = #options,
			Size = _new_udim2(1, 0, 0, ROW_HEIGHT),
			Text = '',
			AutoButtonColor = false,
			Parent = list,
		})

		buttons[option] = button

		local label = create_label({
			Position = _new_udim2(0, 10, 0, 0),
			Size = _new_udim2(1, -20, 1, 0),
			Text = option,
			TextSize = runtime._label_size,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})

		button.MouseEnter:Connect(function()
			_create_tween(tween_service, label, _new_tween_info(0.2), { TextTransparency = 0 }):Play()
		end)

		button.MouseLeave:Connect(function()
			local is_selected = multi and selected[option] or option == current
			_create_tween(tween_service, label, _new_tween_info(0.2), {
				TextTransparency = is_selected and 0.2 or 0.5,
			}):Play()
		end)

		button.MouseButton1Click:Connect(function()
			select_option(option)
		end)
	end

	function dropdown:set_options(next_options, next_selected)
		for _, button in _pairs(buttons) do
			button:Destroy()
		end

		_clear(buttons)
		_clear(options)

		for _, option in next_options or {} do
			add_option(option)
		end

		if multi then
			_clear(selected)
			if _type(next_selected) == 'table' then
				for key, state in _pairs(next_selected) do
					if _type(key) == 'string' and state == true then
						selected[key] = true
					elseif _type(state) == 'string' then
						selected[state] = true
					end
				end
			end
		else
			local candidate = next_selected and _tostring(next_selected) or nil
			current = candidate and _find(options, candidate) and candidate or options[1]
		end

		render_header()
		refresh_labels()

		if dropdown._open then
			list.Size = _new_udim2(1, 0, 0, list_height())
		end
	end

	function dropdown:set_value(value, silent, quiet)
		if multi then
			_clear(selected)
			if _type(value) == 'table' then
				for key, state in _pairs(value) do
					if _type(key) == 'string' and state == true then
						selected[key] = true
					elseif _type(state) == 'string' then
						selected[state] = true
					end
				end
			end
			render_header()
			refresh_labels()
			commit(dropdown:get_value(), silent, quiet)
			return
		end

		value = _tostring(value)
		if not _find(options, value) then
			return
		end

		current = value
		render_header()
		refresh_labels()
		commit(current, silent, quiet)
	end

	function dropdown:unfold(state)
		local target = state
		if target == nil then
			target = not dropdown._open
		end
		if dropdown._locked and not target then
			return
		end
		if target == dropdown._open then
			return
		end

		if target then
			for _, other in runtime._dropdowns do
				if other ~= dropdown and other._open then
					other:unfold(false)
				end
			end
		end

		dropdown._open = target

		_create_tween(tween_service, list, _new_tween_info(0.35, Enum.EasingStyle.Quint), {
			Size = _new_udim2(1, 0, 0, target and list_height() or 0),
		}):Play()

		if not target then
			_delay(0.35, function()
				if not dropdown._open then
					list.CanvasPosition = _new_vector2(0, 0)
				end
			end)
		end
	end

	function dropdown:set_locked_open(state)
		dropdown._locked = state == true
		if dropdown._locked then
			dropdown:unfold(true)
		end
	end

	local header_button = create_new('TextButton', {
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 1, 0),
		Text = '',
		ZIndex = 10,
		Parent = header,
	})

	header_button.MouseButton1Click:Connect(function()
		dropdown:unfold()
	end)

	local initial = shallow_copy(options)
	_clear(options)
	for _, option in initial do
		add_option(option)
	end

	render_header()
	refresh_labels()

	_insert(runtime._dropdowns, dropdown)

	if values.flag then
		library._bind(runtime, values.flag, function(value)
			dropdown:set_value(value, true, true)
		end)
	end


	return dropdown
end

local function create_button(parent, order, values, runtime)
	local button = create_new('TextButton', {
		BackgroundTransparency = 0,
		LayoutOrder = order,
		Size = _new_udim2(1, 0, 0, 28),
		FontFace = FONT,
		Text = values.title or 'Button',
		TextSize = runtime._label_size,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = parent,
	})

	theme.paint(button, 'BackgroundColor3', 'surface_alt')
	theme.paint(button, 'TextColor3', 'text')
	create_round(button, 6)

	button.MouseButton1Click:Connect(function()
		button.BackgroundColor3 = theme.color('stroke')
		_create_tween(tween_service, button, _new_tween_info(0.2), {
			BackgroundColor3 = theme.color('surface_alt'),
		}):Play()

		if values.callback then
			local ok, err = _pcall(values.callback)
			if not ok then
				warn(`[Angeli] button callback failed: {_tostring(err)}`)
			end
		end
	end)


	return button
end

local function create_textbox(parent, order, values, runtime)
	local height = _max(24, tonumber(values.height) or 56)
	local raw = _tostring(values.default or '')

	if values.flag and runtime._flags[values.flag] ~= nil then
		raw = _tostring(runtime._flags[values.flag])
	end

	local frame = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = _new_udim2(1, 0, 0, height + 22),
		ClipsDescendants = true,
		Parent = parent,
	})

	create_label({
		Size = _new_udim2(1, 0, 0, 16),
		Text = values.title or 'Text',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local box = create_new('TextBox', {
		Position = _new_udim2(0, 0, 0, 22),
		Size = _new_udim2(1, 0, 0, height),
		ClearTextOnFocus = false,
		MultiLine = values.multi_line == true,
		PlaceholderText = values.placeholder or '',
		Text = raw,
		TextSize = values.compact and runtime._label_size or runtime._small_size,
		TextWrapped = values.multi_line == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = values.compact and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top,
		FontFace = FONT,
		BorderSizePixel = 0,
		Parent = frame,
	})

	theme.paint(box, 'BackgroundColor3', 'surface_alt')
	theme.paint(box, 'TextColor3', 'text')
	theme.paint(box, 'PlaceholderColor3', 'text_dim')
	create_round(box, 6)
	create_padding(box, 0, 0, 10, 10)

	box.FocusLost:Connect(function(enter)
		if values.flag then
			runtime._flags[values.flag] = raw
			library._save(runtime)
		end
		if values.callback then
			local ok, err = _pcall(values.callback, raw, enter)
			if not ok then
				warn(`[Angeli] textbox callback failed: {_tostring(err)}`)
			end
		end
	end)

	box:GetPropertyChangedSignal('Text'):Connect(function()
		raw = box.Text
	end)

	if values.flag then
		library._bind(runtime, values.flag, function(value)
			raw = _tostring(value or '')
			box.Text = raw
		end)
	end


	return {
		get = function()
			return raw
		end,
		set = function(value)
			raw = _tostring(value or '')
			box.Text = raw
		end,
		clear = function()
			raw = ''
			box.Text = ''
		end,
		focus = function()
			box:CaptureFocus()
		end,
	}
end

local function create_keybind(parent, order, values, runtime)
	local key = values.default or Enum.KeyCode.E

	if _type(key) == 'string' then
		local ok, resolved = _pcall(function()
			return Enum.KeyCode[key]
		end)
		key = ok and resolved or Enum.KeyCode.E
	end

	if values.flag and _type(runtime._flags[values.flag]) == 'string' then
		local ok, resolved = _pcall(function()
			return Enum.KeyCode[runtime._flags[values.flag]]
		end)
		if ok and resolved then
			key = resolved
		end
	end

	local picking = false

	local row = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = _new_udim2(1, 0, 0, 26),
		Parent = parent,
	})

	create_label({
		Size = _new_udim2(0.5, 0, 1, 0),
		Text = values.title or 'Keybind',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local bind = create_new('TextButton', {
		AnchorPoint = _new_vector2(1, 0.5),
		Position = _new_udim2(1, 0, 0.5, 0),
		Size = _new_udim2(0, 36, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT,
		Text = key.Name,
		TextSize = runtime._label_size,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = row,
	})

	theme.paint(bind, 'BackgroundColor3', 'surface_alt')
	theme.paint(bind, 'TextColor3', 'text')
	create_round(bind, 6)
	create_padding(bind, 0, 0, 8, 8)

	bind.MouseButton1Click:Connect(function()
		picking = true
		bind.Text = '...'
	end)

	watch(user_input_service.InputBegan, function(input, processed)
		if picking then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				key = input.KeyCode
				bind.Text = key.Name
				picking = false

				if values.flag then
					runtime._flags[values.flag] = key.Name
					library._save(runtime)
				end

				for _, entry in runtime._keybind_entries do
					if entry.flag == values.flag then
						entry.key_name = key.Name
						break
					end
				end

				library.refresh_keybinds(runtime)
			end
			return
		end

		if not processed and input.KeyCode == key and values.callback then
			local ok, err = _pcall(values.callback)
			if not ok then
				warn(`[Angeli] keybind callback failed: {_tostring(err)}`)
			end
		end
	end)

	if values.flag then
		library.register_keybind(runtime, values.flag, values.title or 'Keybind', key.Name)
	end


	return {
		get = function()
			return key
		end,
	}
end

local function to_hex(color)
	local r = _floor(color.R * 255 + 0.5)
	local g = _floor(color.G * 255 + 0.5)
	local b = _floor(color.B * 255 + 0.5)

	return string.format('#%02X%02X%02X', r, g, b)
end

local function from_hex(text)
	local r, g, b = string.match(_tostring(text or ''), '^#?(%x%x)(%x%x)(%x%x)$')

	if not r then
		return nil
	end

	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function create_colorpicker(parent, order, values, runtime)
	local color = values.default or Color3.fromRGB(255, 255, 255)

	if values.flag and _type(runtime._flags[values.flag]) == 'string' then
		color = from_hex(runtime._flags[values.flag]) or color
	end

	local h, s, v = color:ToHSV()

	local frame = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = _new_udim2(1, 0, 0, 26),
		Parent = parent,
	})

	local header = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 0, 26),
		Parent = frame,
	})

	create_label({
		Size = _new_udim2(1, -40, 1, 0),
		Text = values.title or 'Color',
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})

	local swatch = create_new('TextButton', {
		AnchorPoint = _new_vector2(1, 0.5),
		Position = _new_udim2(1, 0, 0.5, 0),
		Size = _new_udim2(0, 30, 0, 18),
		Text = '',
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = header,
	})

	create_round(swatch, 4)
	create_outline(swatch)

	local panel = create_new('Frame', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, 0, 0, 26),
		Size = _new_udim2(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = frame,
	})

	local sv = create_new('Frame', {
		Size = _new_udim2(1, 0, 0, 96),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = panel,
	})

	create_round(sv, 4)

	local white_layer = create_new('Frame', {
		Size = _new_udim2(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Parent = sv,
	})

	create_new('UIGradient', {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = white_layer,
	})

	local black_layer = create_new('Frame', {
		Size = _new_udim2(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = sv,
	})

	create_new('UIGradient', {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = black_layer,
	})

	local sv_marker = create_new('Frame', {
		AnchorPoint = _new_vector2(0.5, 0.5),
		Size = _new_udim2(0, 10, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = sv,
	})

	create_pill(sv_marker)

	create_new('UIStroke', {
		Thickness = 2,
		Color = Color3.fromRGB(255, 255, 255),
		Parent = sv_marker,
	})

	local hue_bar = create_new('Frame', {
		Position = _new_udim2(0, 0, 0, 104),
		Size = _new_udim2(1, 0, 0, 10),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = panel,
	})

	create_pill(hue_bar)

	local hue_fill = create_new('Frame', {
		Size = _new_udim2(1, 0, 1, 0),
		BorderSizePixel = 0,
		Parent = hue_bar,
	})

	create_new('UIGradient', {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hue_fill,
	})

	local hue_marker = create_new('Frame', {
		AnchorPoint = _new_vector2(0.5, 0.5),
		Position = _new_udim2(h, 0, 0.5, 0),
		Size = _new_udim2(0, 3, 0, 16),
		BorderSizePixel = 0,
		Parent = hue_bar,
	})

	create_new('UIStroke', {
		Thickness = 1,
		Color = Color3.fromRGB(255, 255, 255),
		Parent = hue_marker,
	})

	create_pill(hue_marker)

	local hex_box = create_new('TextBox', {
		Position = _new_udim2(0, 0, 0, 122),
		Size = _new_udim2(1, 0, 0, 24),
		ClearTextOnFocus = false,
		FontFace = FONT,
		PlaceholderText = '#FFFFFF',
		Text = to_hex(color),
		TextSize = runtime._label_size,
		TextXAlignment = Enum.TextXAlignment.Center,
		BorderSizePixel = 0,
		Parent = panel,
	})

	theme.paint(hex_box, 'BackgroundColor3', 'surface_alt')
	theme.paint(hex_box, 'TextColor3', 'text')
	create_round(hex_box, 6)

	local open = false
	local dragging = nil
	local syncing = false

	local function apply(commit, silent, quiet)
		color = Color3.fromHSV(h, s, v)

		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		sv_marker.Position = _new_udim2(s, 0, 1 - v, 0)
		hue_marker.Position = _new_udim2(h, 0, 0.5, 0)
		swatch.BackgroundColor3 = color

		syncing = true
		hex_box.Text = to_hex(color)
		syncing = false

		if not commit then
			return
		end

		if values.flag then
			runtime._flags[values.flag] = to_hex(color)
			if not silent then
				library._save(runtime)
			end
		end

		if values.callback and not quiet then
			local ok, err = _pcall(values.callback, color)
			if not ok then
				warn(`[Angeli] colorpicker callback failed: {_tostring(err)}`)
			end
		end
	end

	local function set_color(next_color, commit, silent, quiet)
		h, s, v = next_color:ToHSV()
		apply(commit, silent, quiet)
	end

	local function toggle_panel(state)
		local target = state
		if target == nil then
			target = not open
		end
		if target == open then
			return
		end

		open = target

		_create_tween(tween_service, panel, _new_tween_info(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = _new_udim2(1, 0, 0, target and 150 or 0),
		}):Play()
	end

	swatch.MouseButton1Click:Connect(function()
		toggle_panel()
	end)

	local function drag_sv(input)
		local size = sv.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end

		s = _clamp((input.Position.X - sv.AbsolutePosition.X) / size.X, 0, 1)
		v = 1 - _clamp((input.Position.Y - sv.AbsolutePosition.Y) / size.Y, 0, 1)
		apply(true)
	end

	local function drag_hue(input)
		local size = hue_bar.AbsoluteSize
		if size.X <= 0 then
			return
		end

		h = _clamp((input.Position.X - hue_bar.AbsolutePosition.X) / size.X, 0, 1)
		apply(true)
	end

	sv.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = 'sv'
			drag_sv(input)
		end
	end)

	hue_bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = 'hue'
			drag_hue(input)
		end
	end)

	watch(user_input_service.InputChanged, function(input)
		if not dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if dragging == 'sv' then
			drag_sv(input)
		else
			drag_hue(input)
		end
	end)

	watch(user_input_service.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)

	hex_box.FocusLost:Connect(function()
		if syncing then
			return
		end

		local parsed = from_hex(hex_box.Text)

		if parsed then
			set_color(parsed, true)
		else
			hex_box.Text = to_hex(color)
		end
	end)

	hex_box:GetPropertyChangedSignal('Text'):Connect(function()
		if syncing then
			return
		end

		local parsed = from_hex(hex_box.Text)
		if parsed then
			set_color(parsed, false)
		end
	end)

	apply(false)

	if values.flag then
		library._bind(runtime, values.flag, function(value)
			local parsed = from_hex(value)
			if parsed then
				set_color(parsed, false, true, true)
			end
		end)
	end


	return {
		get = function()
			return color
		end,
		set = function(next_color)
			set_color(next_color, true)
		end,
		open = function()
			toggle_panel(true)
		end,
	}
end

group_methods = {}

function group_methods:create_toggle(flag, values)
	if _type(flag) == 'table' then
		values = flag
		flag = values.flag
	end
	values = values or {}
	values.flag = flag
	return create_switch(self._frame, self:_next_order(), values, self._runtime)
end

function group_methods:create_slider(flag, values)
	if _type(flag) == 'table' then
		values = flag
		flag = values.flag
	end
	values = values or {}
	values.flag = flag
	return create_slider(self._frame, self:_next_order(), values, self._runtime)
end

function group_methods:create_dropdown(flag, values)
	if _type(flag) == 'table' then
		values = flag
		flag = values.flag
	end
	values = values or {}
	values.flag = flag
	return create_dropdown(self._frame, self:_next_order(), values, self._runtime)
end

function group_methods:create_button(flag, values)
	if _type(flag) == 'table' then
		values = flag
	end
	values = values or {}
	return create_button(self._frame, self:_next_order(), values, self._runtime)
end

function group_methods:create_textbox(flag, values)
	if _type(flag) == 'table' then
		values = flag
		flag = values.flag
	end
	values = values or {}
	values.flag = flag
	return create_textbox(self._frame, self:_next_order(), values, self._runtime)
end

function group_methods:create_colorpicker(flag, values)
	if _type(flag) == 'table' then
		values = flag
		flag = values.flag
	end
	values = values or {}
	values.flag = flag
	return create_colorpicker(self._frame, self:_next_order(), values, self._runtime)
end

function group_methods:create_keybind(flag, values)
	if _type(flag) == 'table' then
		values = flag
		flag = values.flag
	end
	values = values or {}
	values.flag = flag
	return create_keybind(self._frame, self:_next_order(), values, self._runtime)
end

library.group_methods = group_methods

library.new = library._new

library.init = function(builder, runtime_type)
	local runtime = library._new(runtime_type)
	if _type(builder) == 'function' then
		local ok, err = _pcall(builder, runtime)
		if not ok then
			warn(`[Angeli] {_tostring(err)}`)
		end
	end
	return runtime
end

local function call_args(self, ...)
	if _type(self) == 'table' then
		return ...
	end

	return self, ...
end

function library:set_theme(name, persist)
	name, persist = call_args(self, name, persist)
	return theme.apply(name, persist ~= false)
end

function library:themes()
	return theme.list()
end

function library:profiles()
	return save_manager.profiles()
end

function library:save(name)
	name = call_args(self, name)
	return save_manager.save(name)
end

function library:load_profile(name)
	name = call_args(self, name)
	return save_manager.load(name)
end

function library:active_profile()
	return save_manager._active
end

function library:delete_profile(name)
	name = call_args(self, name)
	return save_manager.delete(name)
end

function library:export_profile(name)
	name = call_args(self, name)
	return save_manager.export(name)
end

function library:import_profile(text, name)
	text, name = call_args(self, text, name)
	return save_manager.import(text, name)
end


return library
