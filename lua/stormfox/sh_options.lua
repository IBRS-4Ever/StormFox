-- ConCommand
	concommand.Add("sf_setweather",function( ply, cmd, args, argStr)
		if CLIENT then return end
		StormFox.CanEditWeather(ply,function(argStr)
			StormFox.SetWeather(argStr,1)
		end,argStr)
	end,function(cmd,stringargs)
		--StormFox.GetWeathers()
		stringargs = string.Trim( stringargs )
		stringargs = string.lower( stringargs )
		local tab = {}
		for k, v in ipairs( StormFox.GetWeathers() ) do
			if string.find( string.lower( v ), stringargs ) then
				table.insert( tab, cmd .. " " .. v )
			end
		end
		return tab
	end,"Sets the weather.")

-- SpawnMenu
	if SERVER then

		util.AddNetworkString("StormFox_Settings")
		net.Receive("StormFox_Settings",function(len,ply)
			if not ply then return end
			if (ply.SF_LAST or 0) > SysTime() then return end
				ply.SF_LAST = SysTime() + 0.2
			local con = net.ReadString()
			local arg = net.ReadString()
			if not con then return end
			if not StormFox.convars[con] then return end -- whitelist
			StormFox.CanEditSetting(ply,con,arg or nil)
		end)
	else
		local function requestSetting(con,arg)
			if type(arg) == "boolean" then
				arg = arg and "1" or "0"
			end
			net.Start("StormFox_Settings")
				net.WriteString(con)
				net.WriteString(arg)
			net.SendToServer()
		end
		local function clientTrickBox(panel,con_name,func_disable)
			local con = GetConVar(con_name)
			if not con then return end
			local tickbox = vgui.Create("DCheckBoxLabel",panel)
			tickbox:SetText(con:GetHelpText() or "Unknown setting.")
			tickbox:SetValue(con:GetBool())
			tickbox.con_name = con_name
			tickbox.func_disable = func_disable
			tickbox:SetDark( true )
			function tickbox:OnChange(b)
				RunConsoleCommand(self.con_name,b and "1" or "0")
			end
			function tickbox:Think()
				if not self.con_name then return end
				if func_disable then
					if func_disable(self) then
						self:SetDisabled(true)
					else
						self:SetDisabled(false)
					end
				end
				local ucon = GetConVar(self.con_name)
				if (ucon:GetBool() or true) ~= self:GetValue() then
					self:SetChecked(ucon:GetBool())
				end
			end
			panel:AddItem(tickbox)
			return tickbox
		end
		local function client_settings(panel)
			-- Icon
				local sf_frame = vgui.Create("DPanel",panel)
					sf_frame:SetSize(180,40)
				function sf_frame:Paint() end
				local sf_icon = vgui.Create("DImage",sf_frame)
					sf_icon:SetSize(180,40)
					sf_icon:SetImage("stormfox/StormFox.png")
					sf_icon:SetKeepAspect(false)
				panel:AddPanel(sf_frame)
				panel:AddControl( "Header", { Description = "StormFox Client-Settings" } )
			-- Quality Control

				local cb = panel:AddControl( "checkbox", { Label = "Ultra high quality" } )
				local ultra = cookie.GetNumber("StormFox_ultraqt",0)
					cb:SetValue( ultra )
				BAPQT = panel
				local qt = panel:AddControl( "Slider", { Label = "Weather Quality", Type = "Integer", Command = "sf_exspensive", Min = "0", Max = (ultra == 0 and "7" or "20") } )
					qt.auto = false
				function qt:OnValueChanged(n)
					if n <= 0 then
						self.auto = true
						self:SetText("Weather Quality [AUTO]")
					else
						self.auto = false
						self:SetText("Weather Quality")
					end
				end

				function cb:OnChange(bool)
					if bool then
						cookie.Set("StormFox_ultraqt",1)
						qt:SetMax(20)
					else
						cookie.Set("StormFox_ultraqt",0)
						qt:SetMax(7)
						local con = GetConVar("sf_exspensive")
						if con:GetFloat() > 7 then
							RunConsoleCommand("sf_exspensive","7")
						end
					end
					local con = GetConVar("sf_exspensive")
					qt:SetValue(con:GetFloat())
					qt:UpdateNotches()
				end
				for _,panel in ipairs(qt:GetChildren()) do
					if panel:GetName() == "DSlider" then
						qt.slider = panel
					elseif panel:GetName() == "DTextEntry" then
						qt.label = panel
					end
				end
				function qt:Think()
					if not self.auto then return end
					local vel = StormFox.GetExspensive()
					if self.label then
						self.label:SetText(math.Round(vel,1))
					end

					if not self.slider then return end
					local max = 7 + cookie.GetNumber("StormFox_ultraqt",0) * 13
					self.slider:SetSlideX(math.min(vel / max,1))
				end
			-- Disable effects
				local tick = clientTrickBox(panel,"sf_disableeffects",function(self)
					local con = GetConVar("sf_allowcl_disableeffects")
					local disable = false
					if not con or not con:GetBool() then -- Missing convar
						local xx,yy = self:LocalToScreen(0,0 )
						local x,y = gui.MousePos()
						local w,h = self:GetSize()
						if x > xx and y > yy and x < xx + w and y < yy + h then
							StormFox.DisplayTip(xx,yy,"Disabled on this server.",RealFrameTime())
						end
						return true
					end
				end)
			-- Material
				clientTrickBox(panel,"sf_material_replacment")
			-- Sound
				clientTrickBox(panel,"sf_allow_rainsound")
				clientTrickBox(panel,"sf_allow_windsound")
			-- Dynamic lights
				clientTrickBox(panel,"sf_allow_dynamiclights")
			-- Sunbeams
				clientTrickBox(panel,"sf_allow_sunbeams",function() return not render.SupportsPixelShaders_2_0() end)
			-- Raindrops
				clientTrickBox(panel,"sf_allow_raindrops")
			-- renderscreenspace_effects
				clientTrickBox(panel,"sf_renderscreenspace_effects")
			-- Dynamic shadows
				clientTrickBox(panel,"sf_allow_dynamicshadow")
			-- Dynamic shadows light
				local qt = panel:AddControl( "Slider", { Label = "Dynamiclight Amount", Type = "float", Command = "sf_dynamiclightamount", Min = "0", Max = "5" } )
				local con = GetConVar("sf_dynamiclightamount")
					qt:SetValue(con:GetFloat())
			-- Dynamic shadows
				local ds_button = vgui.Create("DButton",panel)
					ds_button:SetSize(120,30)
					ds_button:SetText("Set HQ shadow convars.")
					ds_button:SetDark(true)
					ds_button.DoClick = function()
						local con = GetConVar("mat_depthbias_shadowmap")
						if con:GetFloat() > 0.00001 then
							print("Setting mat_depthbias_shadowmap to 0.00001")
							RunConsoleCommand("mat_depthbias_shadowmap","0.00001")
						end
						local con2 = GetConVar("r_projectedtexture_filter")
						if con2:GetFloat() > 0.2 then
							print("Setting r_projectedtexture_filter to 0.2")
							RunConsoleCommand("r_projectedtexture_filter","0.2")
						end
					end
				panel:AddPanel(ds_button)
			-- redownloadlightmap
				clientTrickBox(panel,"sf_redownloadlightmaps",function(self)
						local xx,yy = self:LocalToScreen(0,0 )
						local x,y = gui.MousePos()
						local w,h = self:GetSize()
						if x > xx and y > yy and x < xx + w and y < yy + h then
							StormFox.DisplayTip(xx,yy,"Disabled as it causes light-errors turning this off.",RealFrameTime())
						end
						return true
					end)
				local textbox = vgui.Create("DLabel",panel)
					textbox:SetSize(120,26)
					textbox:SetDark(true)
					textbox:SetText("Warning! This option might require you to rejoin when \ndisabled and can cause lag on large maps.")
				panel:AddPanel(textbox)
		end
		local function adminTrickBox(panel,con_name)
			local con = GetConVar(con_name)
			if not con then return end
			local tickbox = vgui.Create("DCheckBoxLabel",panel)
			tickbox:SetText(con:GetHelpText() or "Unknown setting.")
			tickbox:SetValue(con:GetBool())
			tickbox.con_name = con_name
			tickbox:SetDark( true )
			function tickbox:OnChange(b)
				requestSetting(self.con_name,b and "1" or "0")
			end
			function tickbox:Think()
				if self.Think2 then self:Think2() end
				if not self.con_name then return end
				local ucon = StormFox.GetNetworkData("con_" .. self.con_name)
				if (ucon == "1") ~= self:GetValue() then
					self:SetChecked(ucon == "1")
				end
			end
			panel:AddItem(tickbox)
			return tickbox
		end
		local function admin_settings(panel)
			-- Icon
				local sf_frame = vgui.Create("DPanel",panel)
					sf_frame:SetSize(180,40)
				function sf_frame:Paint() end
				local sf_icon = vgui.Create("DImage",sf_frame)
					sf_icon:SetSize(180,40)
					sf_icon:SetImage("stormfox/StormFox.png")
					sf_icon:SetKeepAspect(false)
					sf_icon:SetImageColor(Color(255,255,0))
				panel:AddPanel(sf_frame)
				panel:AddControl( "Header", { Description = "StormFox Server-Settings (Admin only)" } )
			-- MoonScale
				local con = GetConVar("sf_moonscale")
				local ms = 6
				if con then
					ms = con:GetFloat() or 6
				end
				local moon_scale = vgui.Create("DNumSlider",panel)
					moon_scale:SetText("Moon Scale")
					moon_scale:SetMin(0)
					moon_scale:SetMax(80)
					moon_scale:SetDecimals(0)
					moon_scale:SetValue(ms)
					moon_scale:SizeToContents()
					moon_scale:SetDark( true )
				function moon_scale:OnValueChanged(n)
					requestSetting("sf_moonscale",math.Round(n) .. "")
				end
				panel:AddItem(moon_scale)
			-- SunMoonAngle
				local con = GetConVar("sf_sunmoon_yaw")
				local ms = 270
				if con then
					ms = con:GetFloat() or 270
				end
				local moon_scale = vgui.Create("DNumSlider",panel)
					moon_scale:SetText(con:GetHelpText())
					moon_scale:SetMin(0)
					moon_scale:SetMax(360)
					moon_scale:SetDecimals(0)
					moon_scale:SetValue(ms)
					moon_scale:SizeToContents()
					moon_scale:SetDark( true )
				function moon_scale:OnValueChanged(n)
					requestSetting("sf_sunmoon_yaw",math.Round(n) .. "")
				end
				panel:AddItem(moon_scale)
			-- Allow people to disable effects
				local de_button = adminTrickBox(panel,"sf_allowcl_disableeffects")
				function de_button:Think2()
					local xx,yy = self:LocalToScreen(0,0 )
					local x,y = gui.MousePos()
					local w,h = self:GetSize()
					if x > xx and y > yy and x < xx + w and y < yy + h then
						StormFox.DisplayTip(xx,yy,"Allows clients to disable SF effects. (Clients might get an unfair advantage in heavy rain with this.)",RealFrameTime())
					end
				end
			-- Follow localtime
				adminTrickBox(panel,"sf_realtime")
			-- Disable autoweather
				adminTrickBox(panel,"sf_disable_autoweather")
			-- Disable fog
				adminTrickBox(panel,"sf_disablefog")
			-- Disable windpush
				adminTrickBox(panel,"sf_disable_windpush")
			-- Disable damage and debuffs
				adminTrickBox(panel,"sf_disableweatherdebuffs")
			-- Disable lightning bolts
				adminTrickBox(panel,"sf_disablelightningbolts")
			-- Disable skybox
				adminTrickBox(panel,"sf_disableskybox")
			-- Disable light bloom
				adminTrickBox(panel,"sf_disable_mapbloom")
			-- Disable sf mapbrowser changing maps
				adminTrickBox(panel,"sf_disblemapbrowser")
			-- Disable mapsupport
				adminTrickBox(panel,"sf_disable_mapsupport")
				local textbox = vgui.Create("DLabel",panel)
					textbox:SetSize(120,14)
					textbox:SetDark(true)
					textbox:SetText("        (Requires mapchange to work.)")
				panel:AddPanel(textbox)
			-- Weather Menu
				local ds_button = vgui.Create("DButton",panel)
					ds_button:SetSize(120,30)
					ds_button:SetText("Open weather menu.")
					ds_button:SetDark(true)
					ds_button.DoClick = function()
						if StormFox.OpenWeatherMenu then
							StormFox.OpenWeatherMenu()
						end
					end
				panel:AddPanel(ds_button)
			-- Map settings
				local ms_button = vgui.Create("DButton",panel)
					ms_button:SetSize(120,30)
					ms_button:SetText("Open map settings.")
					ms_button:SetDark(true)
					ms_button.DoClick = function()
						StormFox.MapSettings()
						LocalPlayer():EmitSound("ui/buttonclickrelease.wav")
					end

				panel:AddPanel(ms_button)
			-- Map browser
				local ds_button = vgui.Create("DButton",panel)
					ds_button:SetSize(120,30)
					ds_button:SetText("Open map browser.")
					ds_button:SetDark(true)
					ds_button.DoClick = function()
						RunConsoleCommand("sf_open_mapbrowser")
						LocalPlayer():EmitSound("ui/buttonclickrelease.wav")
					end

				panel:AddPanel(ds_button)
			-- Debugger
				adminTrickBox(panel,"sf_debugcompatibility")
				local textbox = vgui.Create("DLabel",panel)
				textbox:SetSize(120,14)
					textbox:SetDark(true)
					textbox:SetText("        (Requires mapchange and will override hook.Call)")
				panel:AddPanel(textbox)
			-- Ekstra lightsupport
				adminTrickBox(panel,"sf_enable_ekstra_lightsupport")
				local textbox = vgui.Create("DLabel",panel)
				textbox:SetSize(120,14)
					textbox:SetDark(true)
					textbox:SetText("        (Can lag on large maps!)")
				panel:AddPanel(textbox)
			-- Block removal of light_environment
				local block = adminTrickBox(panel,"sf_block_lightenvdelete")
				local textbox = vgui.Create("DLabel",panel)
				textbox:SetSize(120,14)
					textbox:SetDark(true)
					textbox:SetText("        (Can cause light-flickering)")
				panel:AddPanel(textbox)
				function block:Think2()
					local xx,yy = self:LocalToScreen(0,0 )
					local x,y = gui.MousePos()
					local w,h = self:GetSize()
					if x > xx and y > yy and x < xx + w and y < yy + h then
						StormFox.DisplayTip(xx,yy,"Prevents the entity from getting deleted. However this can cause some light-flickering and requires map-restart when toggled.",RealFrameTime())
					end
				end

		end
		hook.Add( "PopulateToolMenu", "Populate StormFox Menus", function()
			spawnmenu.AddToolMenuOption( "Options", "StormFox", "User_StormFox", "Client Settings", "", "", client_settings )
			spawnmenu.AddToolMenuOption( "Options", "StormFox", "Admin_StormFox", "Server Settings", "", "", admin_settings )
		end )
		hook.Add( "AddToolMenuCategories", "Create StormFox Categories", function()
			spawnmenu.AddToolCategory( "Options", "StormFox", "StormFox Settings" )
		end )
	end
-- GUI Weather Menu
	if SERVER then
		util.AddNetworkString("StormFox - WeatherC")
		net.Receive("StormFox - WeatherC",function(len,ply)
			if not ply:IsAdmin() then ply:EmitSound("common/wpn_denyselect.wav") return end -- Noooope
			if not ply:GetEyeTrace().Entity then ply:EmitSound("common/wpn_denyselect.wav") return end
			ply:EmitSound("common/bugreporter_succeeded.wav")
			local msg = net.ReadBool()
			local str = net.ReadString()
			local var = net.ReadType()
			StormFox.CanEditWeather(ply,function(str,var,msg)
				if msg == false then
					StormFox.SetWeather(str,var)
				elseif str == "time_set" then
					StormFox.SetTime(var)
				elseif str == "time_speed" then
					RunConsoleCommand("sf_timespeed",var)
				elseif type(var) == "number" and str ~= "WindAngle" then
					StormFox.SetNetworkData(str,var,2)
				else
					StormFox.SetNetworkData(str,var)
				end
			end,str,var,msg)
		end)
	else
	-- Fonts, functions and data
		surface.CreateFont( "SkyFox-Console_B", {
			font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
			extended = false,
			size = 30,
			weight = 500,
			blursize = 0,
			scanlines = 0,
			antialias = true,
			underline = false,
			italic = false,
			strikeout = false,
			symbol = false,
			rotary = false,
			shadow = false,
			additive = false,
			outline = false,
		} )
		surface.CreateFont( "SkyFox-Console", {
			font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
			extended = false,
			size = 20,
			weight = 500,
			blursize = 0,
			scanlines = 0,
			antialias = true,
			underline = false,
			italic = false,
			strikeout = false,
			symbol = false,
			rotary = false,
			shadow = false,
			additive = false,
			outline = false,
		} )
		surface.CreateFont( "SkyFox-Console_Small", {
			font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
			extended = false,
			size = 14,
			weight = 500,
			blursize = 0,
			scanlines = 0,
			antialias = true,
			underline = false,
			italic = false,
			strikeout = false,
			symbol = false,
			rotary = false,
			shadow = false,
			additive = false,
			outline = false,
		} )
		STORMFOX_WPANEL = STORMFOX_WPANEL or nil
		local colors = {}
			colors[1] = Color(241,223,221,255)
			colors[2] = Color(78,85,93,255)
			colors[3] = Color(51,56,60)
			colors[4] = Color(47,50,55)
		local weathers = {}
		local tselected = 1
		hook.Add("StormFox - PostInit","StormFox - MenuInit",function()
			weathers = StormFox.GetWeathers()
			tselected = StormFox.GetWeathersDefaultNumber()
		end)
		local tselectedamount = 0.8
		local clamp,round,floor,cos,sin,rad = math.Clamp,math.Round,math.floor,math.cos,math.sin,math.rad

		local sf_icon = Material("stormfox/sf.png","noclamp")
		local grad = Material("gui/gradient_up")
		local m_arrow = Material("gui/arrow")
		local m_thunder = Material("stormfox/symbols/thunder.png")
		local m_cloudy = Material("stormfox/symbols/Cloudy.png")
		local m_cir = Material("vgui/circle")

		local function CreateButton(panel,text)
			local button = vgui.Create("DButton",panel)
			button:SetText("")
			button:SetSize(120,22)
			button.text = text or ""
			function button:Paint(w,h)
				if self:IsDown() then
					surface.SetDrawColor(colors[3])
				else
					surface.SetDrawColor(colors[2])
				end
				surface.DrawRect(0,0,w,h)
				surface.SetMaterial(grad)
				surface.SetDrawColor(colors[3])
				surface.DrawTexturedRect(0,0,w,h)
				surface.SetDrawColor(colors[4])
					surface.DrawLine(0,0,w,0)
					surface.DrawLine(0,0,0,h)
					surface.DrawLine(w - 1,0,w - 1,h)
					surface.DrawLine(w - 1,0,w - 1,h - 1)
				local col = Color(241,223,221)
				if self:IsDown() then
					col.a = 25
				end
				local e = ""
				if self.editing and SysTime() % 2 < 1 then
					e = "_"
				end
				surface.SetTextColor(col)
				surface.SetFont("SkyFox-Console")
				local tw,th = surface.GetTextSize(self.text .. e)
				surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2)
				surface.DrawText(self.text .. e)
			end
			return button
		end
		local function CreateSmallButton(panel,text)
			local button = vgui.Create("DButton",panel)
			button:SetText("")
			button:SetSize(60,12)
			button.text = text or ""
			function button:Paint(w,h)
				if self:IsDown() then
					surface.SetDrawColor(colors[3])
				else
					surface.SetDrawColor(colors[2])
				end
				surface.DrawRect(0,0,w,h)
				surface.SetMaterial(grad)
				surface.SetDrawColor(colors[3])
				surface.DrawTexturedRect(0,0,w,h)
				surface.SetDrawColor(colors[4])
					surface.DrawLine(0,0,w,0)
					surface.DrawLine(0,0,0,h)
					surface.DrawLine(w - 1,0,w - 1,h)
					surface.DrawLine(w - 1,0,w - 1,h - 1)
				local col = Color(241,223,221)
				if self:IsDown() then
					col.a = 25
				end
				surface.SetTextColor(col)
				surface.SetFont("SkyFox-Console_Small")
				local tw,th = surface.GetTextSize(self.text)
				surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2)
				local e = ""
				if self.editing and SysTime() % 2 == 1 then
					e = "_"
				end
				surface.DrawText(self.text .. e)
			end
			return button
		end
		local function CreateSlider(panel,wi,he)
			local slider = vgui.Create("DButton",panel)
				slider:SetText("")
				slider:SetSize(wi,he)
				slider.var = 0
			function slider:Paint(w,h)
				surface.SetDrawColor(Color(255,255,255,5))
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(colors[3])
				surface.DrawRect(w * 0.05,h / 2 - 1,w * 0.9,2)

				surface.SetDrawColor(colors[1])
				surface.DrawRect(w * 0.05,h / 2 - 1,w * 0.9 * self.var,2)

				surface.DrawRect(w * 0.05 + w * 0.9 * self.var,0,2,h)
			end
			return slider
		end
	-- Chat status
		local openChat = false
		hook.Add("StartChat","StormFox DisableC",function()
			openChat = true
		end)
		hook.Add("FinishChat","StormFox EnableC",function()
			openChat = false
		end)
	-- Map Display
		local mat = Material("gui/gradient")
		local cross = Material("debug/particleerror")
		local check = Material("vgui/hud/icon_check")
		local function drawStatus(name,x,y,bool,helptext,self)
			local cx,cy = self:CursorPos()
			surface.SetTextPos(x + 19,y)
			if bool then
				surface.SetTextColor(0,255,0)
				surface.SetDrawColor(255,255,255)
				surface.SetMaterial(check)
			else
				surface.SetTextColor(255,255,255)
				surface.SetDrawColor(255,0,0)
				surface.SetMaterial(cross)
			end
			if cx > x and cx < x + 150 and cy > y and cy < y + 16 then
				local xx,yy = self:LocalToScreen( x,y + 7 )
				StormFox.DisplayTip(xx,yy,helptext,1)
			end
			surface.SetFont("SkyFox-Console_Small")
			surface.DrawText(name)
			surface.DrawTexturedRect(x,y + 1,14,14)
		end

		local function OpenMapDisplay()
			if not STORMFOX_WPANEL or not IsValid(STORMFOX_WPANEL) then return end
			if STORMFOX_MPANEL and IsValid(STORMFOX_MPANEL) then
				STORMFOX_MPANEL:Remove()
			end
			local panel = vgui.Create("DPanel")
			local w,h = 150,154
			panel.h = h
			panel:SetSize(w,h)
			local x,y = STORMFOX_WPANEL:GetPos()
			panel:SetPos(x - w,y + 24)
			function panel:Think()
				if not STORMFOX_WPANEL or not IsValid(STORMFOX_WPANEL) then self:Remove() end
			end
			function panel.Paint(self,w,h)
				local cx,cy = self:CursorPos()
				surface.SetDrawColor(colors[2])
				surface.SetDrawColor(Color(0,0,0,100))
				surface.SetMaterial(mat)
				surface.DrawRect(0,0,w,self.h)
				surface.DrawTexturedRectRotated(w - 10 ,self.h / 2,20,self.h,180)
				surface.DrawTexturedRectRotated(10 ,self.h / 2,20,self.h,0)
				draw.DrawText("Map Entities","SkyFox-Console_Small",w / 2,0,Color(255,255,255),1)
				local t = {}
					t["light_environment"] = "Enables smooth light-controls and doesn't require extra light support to make the map dark."
					t["env_tonemap_controller"] = "Enables light-bloom/tonemap effects."
					t["env_fog_controller"] = "Allows to control and edit fog."
					t["env_skypaint"] = "Allows to paint and edit the sky."
					t["shadow_control"] = "This map have source shadows."

				local y = 0
				local i = 0
				for str,helptext in pairs(t) do
					i = i + 1
					local b = StormFox.GetNetworkData("has_" .. str,false)
					drawStatus(str,5,i * 16,b,helptext,self)
					y = i * 16 + 16
				end
				drawStatus("3D skybox",5,y,StormFox.Is3DSkybox(),"Allows better and further distant dynamic light.",self)

				if StormFox.GetNetworkData("has_trigger",false) then
					draw.DrawText("Extra map support","SkyFox-Console_Small",w / 2,y + 16,Color(255,255,255),1)
					drawStatus("Map Effects/ Triggers",5,y + 32,true,"This map have extra light-effects and triggers.",self)
					y = y + 49
				end
				self.h = y + 19
			end

			STORMFOX_MPANEL = panel
			return panel
		end
	-- HUDMenu
		local m_info = Material("icon16/information.png")
		local m_browser = Material("icon16/map.png")
		function StormFox.OpenWeatherMenu()
			if STORMFOX_WPANEL and IsValid(STORMFOX_WPANEL) then
				STORMFOX_WPANEL:Remove()
			end
			weathers = StormFox.GetWeathers()
			tselected = StormFox.GetWeathersDefaultNumber()

			local pw,ph = 180,378 --354
			panel = vgui.Create("DFrame")
				panel:SetTitle("StormFox " .. StormFox.Version)
				panel:SetSize(pw,ph)
				function panel.Paint(self,w,h)
					surface.SetDrawColor(colors[2])
					surface.DrawRect(0,0,w,h)
					surface.SetDrawColor(colors[4])
					surface.DrawRect(0,0,w,24)
				end
				panel.enabled = false
			-- Map Details
				local MapInfo_Button = vgui.Create("DButton",panel)
					function MapInfo_Button:Paint() end
					MapInfo_Button:SetText("")
					MapInfo_Button:SetSize(22,22)
					MapInfo_Button:SetPos(pw - 62,1)
					function MapInfo_Button:PaintOver(w,h)
						surface.SetDrawColor(Color(255,255,255))
						surface.SetMaterial(m_info)
						surface.DrawTexturedRect(w * 0.1,h * 0.1,w * 0.85,h * 0.85)
					end
					function MapInfo_Button:DoClick()
						if STORMFOX_MPANEL and IsValid(STORMFOX_MPANEL) then
							STORMFOX_MPANEL:Remove()
						else
							OpenMapDisplay()
						end
						LocalPlayer():EmitSound("ui/buttonclick.wav")
					end
			-- Map browser
				local MapInfo_Button = vgui.Create("DButton",panel)
					function MapInfo_Button:Paint() end
					MapInfo_Button:SetText("")
					MapInfo_Button:SetSize(22,22)
					MapInfo_Button:SetPos(pw - 84,1)
					function MapInfo_Button:PaintOver(w,h)
						surface.SetDrawColor(Color(255,255,255))
						surface.SetMaterial(m_browser)
						surface.DrawTexturedRect(w * 0.1,h * 0.1,w * 0.85,h * 0.85)
					end
					function MapInfo_Button:DoClick()
						RunConsoleCommand("sf_open_mapbrowser")
						LocalPlayer():EmitSound("ui/buttonclickrelease.wav")
					end
			-- Select Weather
				local SetWeather = CreateButton(panel,"Set Weather")
				SetWeather:SetPos(pw / 2 - 60,28)
				local mat = StormFox.GetWeatherType(weathers[tselected]):GetStaticIcon( )
				local selectedweather = vgui.Create("DImage",panel)
					selectedweather:SetSize(32,32)
					selectedweather:SetMaterial(mat)
					selectedweather:SetPos(pw / 2 - 16,58)

				local prev = vgui.Create("DButton",panel)
					prev:SetText("")
					prev:SetSize(32,32)
					prev:SetPos(pw / 2 - 48,58)
					function prev:Paint(w,h)
						if self:IsDown() then
							surface.SetDrawColor(colors[1])
						else
							surface.SetDrawColor(255,255,255)
						end
						surface.SetMaterial(m_arrow)
						surface.DrawTexturedRectRotated(w / 2,h / 2,w * 0.8,h * 0.8,90)
					end
				local _next = vgui.Create("DButton",panel)
					_next:SetText("")
					_next:SetSize(32,32)
					_next:SetPos(pw / 2 + 16,58)
					function _next:Paint(w,h)
						if self:IsDown() then
							surface.SetDrawColor(colors[1])
						else
							surface.SetDrawColor(255,255,255)
						end
						surface.SetMaterial(m_arrow)
						surface.DrawTexturedRectRotated(w / 2,h / 2,w * 0.8,h * 0.8,270)
					end

				function prev:DoClick()
					tselected = tselected - 1
					if tselected <= 0 then
						tselected = #weathers
					end
					local mat = StormFox.GetWeatherType(weathers[tselected]):GetStaticIcon( )
					selectedweather:SetMaterial(mat)
				end
				function _next:DoClick()
					tselected = tselected + 1
					if tselected > #weathers then
						tselected = 1
					end
					local mat = StormFox.GetWeatherType(weathers[tselected]):GetStaticIcon( )
					selectedweather:SetMaterial(mat)
				end
				function SetWeather:DoClick()
					net.Start("StormFox - WeatherC")
						net.WriteBool(false)
						net.WriteString(weathers[tselected])
						net.WriteType(tselectedamount)
					net.SendToServer()
				end
				local slider = CreateSlider(panel,140,14)
					slider:SetPos(pw / 2 - 70,92)
					slider.var = tselectedamount
				function slider:DoClick()
					local w,h = self:GetSize()
					local x,y = self:CursorPos()
					local percent = clamp((x - w * 0.05) / (w * 0.9),0,1) -- w * 0.9
					tselectedamount = percent
					self.var = percent
				end
			-- Thunder
				local thunder = CreateButton(panel,"")
					thunder:SetText("")
					thunder:SetSize(28,28)
					thunder:SetPos(pw - (pw / 4) + 8,58)
					function thunder:PaintOver(w,h)
						local thunder = StormFox.GetNetworkData("Thunder",false)
						if not thunder then
							surface.SetDrawColor(Color(0,0,0))
						else
							surface.SetDrawColor(Color(255,255,255))
						end
						
						local tl = StormFox.GetNetworkData("ThunderLight",0)
						surface.SetMaterial(m_thunder)
						surface.DrawTexturedRect(w * 0.1,h * 0.1,w * 0.8,h * 0.8)

						surface.SetDrawColor(colors[1])
						surface.SetMaterial(m_cloudy)
						surface.DrawTexturedRect(w * 0.1,h * 0.1 - h * 0.2,w * 0.8,h * 0.8)
					end
				function thunder:DoClick()
					net.Start("StormFox - WeatherC")
						net.WriteBool(true)
						net.WriteString("Thunder")
						local thunder = StormFox.GetNetworkData("Thunder",false)
						net.WriteType(not thunder)
					net.SendToServer()
				end
			-- Temperature
				local label = vgui.Create("DLabel",panel)
					label:SetText("")
					label:SetSize(160,20)
					label:SetPos(pw / 2 - 80,106)
					local n = round(StormFox.GetNetworkData("Temperature",20),1)
					label.text = "Temperature: " .. n .. "°C - " .. round(StormFox.CelsiusToFahrenheit(n),1) .. "°F"
					function label:Paint(w,h)
						local n = round(StormFox.GetNetworkData("Temperature",20),1)
						label.text = "Temperature: " .. n .. "°C - " .. round(StormFox.CelsiusToFahrenheit(n),1) .. "°F"
						surface.SetTextColor(colors[1])
						surface.SetFont("SkyFox-Console_Small")
						local tw,th = surface.GetTextSize(label.text)
						surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2)
						surface.DrawText(label.text)
					end
				local tslider = CreateSlider(panel,140,14)
					tslider:SetPos(pw / 2 - 70,122)
					tslider.var = (10 + StormFox.GetNetworkData("Temperature",0)) / 50
					function tslider:DoClick()
						local w,h = self:GetSize()
						local x,y = self:CursorPos()
						local percent = clamp((x - w * 0.05) / (w * 0.9),0,1) -- w * 0.9
						net.Start("StormFox - WeatherC")
							net.WriteBool(true)
							net.WriteString("Temperature")
							net.WriteType(percent * 50 - 10)
						net.SendToServer()
					end
					function tslider:Think()
						self.var = (10 + StormFox.GetNetworkData("Temperature",0)) / 50
					end
			-- Wind
				local label = vgui.Create("DLabel",panel)
					label:SetText("")
					label:SetSize(160,20)
					label:SetPos(pw / 2 - 80,134)
					local n = round(StormFox.GetNetworkData("Wind",0),1)
					label.text = "Wind: " .. n
					function label:Paint(w,h)
						local n = round(StormFox.GetNetworkData("Wind",0),1)
						local b,str = StormFox.GetBeaufort(n)
						label.text = "Wind: " .. n .. " " .. str
						surface.SetTextColor(colors[1])
						surface.SetFont("SkyFox-Console_Small")
						local tw,th = surface.GetTextSize(label.text)
						surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2)
						surface.DrawText(label.text)
					end
				local tslider = CreateSlider(panel,140,14)
					tslider:SetPos(pw / 2 - 70,150)
					tslider.var = StormFox.GetNetworkData("Wind",0) / 50
					function tslider:DoClick()
						local w,h = self:GetSize()
						local x,y = self:CursorPos()
						local percent = clamp((x - w * 0.05) / (w * 0.9),0,1) -- w * 0.9
						net.Start("StormFox - WeatherC")
							net.WriteBool(true)
							net.WriteString("Wind")
							net.WriteType(percent * 50)
						net.SendToServer()
					end
					function tslider:Think()
						self.var = StormFox.GetNetworkData("Wind",0) / 50
					end
			-- WindAngle
				local windang = vgui.Create("DButton",panel)
					windang:SetSize(80,80)
					windang:SetPos(pw / 2 - 40,122 + 56)
					windang:SetText("")
				function windang:Paint(w,h)
					-- Generate poly
					surface.SetDrawColor(colors[4])
					surface.SetMaterial(m_cir)
					surface.DrawTexturedRect(0,0,w,h)

					local windang = EyeAngles().y - StormFox.GetNetworkData("WindAngle",0)
					local t = {{x = w / 2,y = h / 2}}
					local l = clamp(StormFox.GetNetworkData("Wind",0),0,40) / 2
					if l < 1 then
						surface.SetDrawColor(155,255,155)
						l = 2
					else
						surface.SetDrawColor(155,155,255)
					end
					local nn = 90 - l * 5
					for i = 0,l - 1 do
						local x = cos(rad(i * 10 + windang + nn)) * w / 2 + w / 2
						local y = sin(rad(i * 10 + windang + nn)) * h / 2 + h / 2
						table.insert(t,{x = x,y = y})
					end
					local x = cos(rad(l * 10 + windang + nn)) * w / 2 + w / 2
					local y = sin(rad(l * 10 + windang + nn)) * h / 2 + h / 2
					table.insert(t,{x = x,y = y})

					draw.NoTexture()
					surface.DrawPoly(t)
					surface.SetDrawColor(Color(0,0,0,255))
					surface.SetMaterial(m_cir)
					local n = 5
					surface.DrawTexturedRect(n - 0.5,n - 0.5,w - n * 2 + 2,h - n * 2 + 2)
					if self:IsDown() then
						surface.SetDrawColor(colors[3])
					else
						surface.SetDrawColor(colors[2])
					end
					surface.DrawTexturedRect(n,n,w - n * 2,h - n * 2)
					local text = "Set WindAngle"
					surface.SetFont("SkyFox-Console_Small")
					local tw,th = surface.GetTextSize(text)
					surface.SetTextColor(colors[1])
					surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2)
					surface.DrawText(text)
				end
				function windang:DoClick()
					net.Start("StormFox - WeatherC")
						net.WriteBool(true)
						net.WriteString("WindAngle")
						net.WriteType(EyeAngles().y + 180)
					net.SendToServer()
				end
			-- Time options
				local ampm = cookie.GetNumber("stormfox-ampm",0)
				local settimeoption = vgui.Create("DPanel",panel)
					settimeoption:SetSize(pw - 40,24)
					settimeoption:SetPos(20,280)
				local function SetTimeOption()
					for k,v in pairs(settimeoption:GetChildren()) do
						v:Remove()
					end
					local ampm = cookie.GetNumber("stormfox-ampm",0)
					local sw,sh = settimeoption:GetSize()
					local time = StormFox.GetRealTime(nil,ampm == 1)
					local h = string.match(time,"(%d+):")
					local m = string.match(time,":(%d+)")
					local a = string.match(time,":%d+%s?(.+)") or ""
					settimeoption.htext = {h,m,a}

					local hour = CreateButton(settimeoption,h)
					settimeoption.hour = hour
						hour.editing = false
					local min = CreateButton(settimeoption,m)
					settimeoption.min = min
						min.editing = false
					local s = sw / (ampm == 0 and 2 or 3)
					hour:SetSize(s,sh)
					hour.hour = true
					hour.ampm = ampm
					min:SetSize(s,sh)
					min.ampm = ampm
					min:SetPos(s,0)
					function hour:DoClick()
						self.editing = not self.editing
						min.editing = false
					end
					function min:DoClick()
						self.editing = not self.editing
						hour.editing = false
					end
					local Think = function(self)
						if self.editing and not self.oldtext then
							self.oldtext = self.text
							self.text = ""
						elseif (not self.editing or #self.text >= 2 or input.IsKeyDown(64)) and self.oldtext then
							if #self.text < 1 or string.match(self.text,"%d+") ~= self.text then
								self.text = self.oldtext
							end
							local min = self.hour and (ampm == 1 and 1 or 0) or 0
							local max = self.hour and (ampm == 1 and 12 or 23) or 59
							if tonumber(self.text) > max then
								self.text = max
							elseif tonumber(self.text) < min then
								self.text = min
							elseif tonumber(self.text) ~= self.text then
								self.text = tonumber(self.text)
							end
							self.oldtext = nil
							self.editing = false
						elseif self.editing then
							for i = 0,9 do
								if input.IsKeyDown(i + 1) and i ~= self.lastkey then
									self.text = self.text .. i
									self.lastkey = i
								end
							end
							if self.lastkey and not input.IsKeyDown(self.lastkey + 1) then
								self.lastkey = nil
							end
						end
					end
					hour.Think = Think
					min.Think = Think

					if ampm == 1 then
						local ampmb = CreateButton(settimeoption,a)
						settimeoption.ampmb = ampmb
						ampmb:SetSize(math.ceil(s),sh)
						ampmb:SetPos(s * 2,0)
						function ampmb:DoClick()
							ampmb.text = (ampmb.text == "AM" and "PM" or "AM")
							settimeoption.htext[3] = ampmb.text
							LocalPlayer():EmitSound("ui/buttonclick.wav")
						end
					end
				end
				SetTimeOption()

				local ampmtoggle = CreateSmallButton(panel,ampm == 0 and "AM/PM" or "24 clock")
					ampmtoggle:SetSize(60,12)
					ampmtoggle:SetPos(20,264)
				function ampmtoggle:DoClick()
					LocalPlayer():EmitSound("ui/buttonclick.wav")
					ampm = 1 - ampm
					ampmtoggle.text = ampm == 0 and "AM/PM" or "24 clock"
					cookie.Set("stormfox-ampm",ampm .. "")
					SetTimeOption()
				end
				local settimebutton = CreateButton(panel,"SetTime")
				settimebutton:SetSize(pw - 40,24)
				settimebutton:SetPos(20,308)
				function settimebutton:DoClick()
					local str = settimeoption.hour.text .. ":" .. settimeoption.min.text
					if settimeoption.ampmb and settimeoption.ampmb.text then
						str = str .. settimeoption.ampmb.text or "AM"
					end
					net.Start("StormFox - WeatherC")
						net.WriteBool(true)
						net.WriteString("time_set")
						net.WriteType(str)
					net.SendToServer()
				end
			-- Time speed
				local symbol = CreateButton(panel,"")
					symbol:SetSize(18,18)
					symbol:SetPos(pw / 2 - 78,338)
					symbol.symbol = Material("stormfox/symbols/time_default.png")
				function symbol:PaintOver(w,h)
					surface.SetDrawColor(Color(255,255,255))
					surface.SetMaterial(self.symbol)
					surface.DrawTexturedRect(0,0,w,h)
				end
				function symbol:DoClick()
					local cur = StormFox.GetTimeSpeed()
					local default = self.default or 1
					if cur > 0 then
						self.default = cur
						-- Set 0
						net.Start("StormFox - WeatherC")
							net.WriteBool(true)
							net.WriteString("time_speed")
							net.WriteType("0")
						net.SendToServer()
					else
						-- Set self.default
						net.Start("StormFox - WeatherC")
							net.WriteBool(true)
							net.WriteString("time_speed")
							net.WriteType((self.default or 1) .. "")
						net.SendToServer()
					end
				end
				local time_speed = CreateSlider(panel,140,14)
				time_speed:SetPos(pw / 2 - 60,340)
				time_speed.oldVar = -1
				function time_speed:Paint(w,h)
					surface.SetDrawColor(Color(255,255,255,5))
					surface.DrawRect(0,0,w,h)
					for i = 0,1 do
						local lv = i / 4
						if self.var < lv then
							surface.SetDrawColor(colors[3])
						else
							surface.SetDrawColor(colors[1])
						end
						surface.DrawRect(w * 0.05 + w * 0.9 * lv,0,2,h)
					end
					surface.SetDrawColor(colors[3])
					surface.DrawRect(w * 0.05,h / 2 - 1,w * 0.9,2)

					surface.SetDrawColor(colors[1])
					surface.DrawRect(w * 0.05,h / 2 - 1,w * 0.9 * self.var,2)

					surface.DrawRect(w * 0.05 + w * 0.9 * self.var,0,2,h)
					surface.SetDrawColor(colors[3])
				end
				function time_speed:DoClick()
					local w,h = self:GetSize()
					local x,y = self:CursorPos()
					local procent = clamp((x - w * 0.05) / (w * 0.9),0,1)
					local speed = procent * 4
					if procent > 0.25 then
						speed = 1 + (procent - 0.25) * 42.66
					end
					if speed > 0.8 and speed < 1.85 then
						speed = 1
					else
						for i = 1,3 do
							local cur = math.Round(1 + (i * 0.25) * 42.66,1)
							local curmin, curmax = 1 + (i * 0.25 - 0.05) * 42.66,1 + (i * 0.25 + 0.05) * 42.66
							if speed > curmin and speed < curmax then
								speed = cur
								break
							end
						end
					end

					net.Start("StormFox - WeatherC")
						net.WriteBool(true)
						net.WriteString("time_speed")
						net.WriteType(speed .. "")
					net.SendToServer()
				end
				function time_speed:Think()
					local cur = StormFox.GetTimeSpeed()
					if time_speed.oldVar == cur then return end
					time_speed.oldVar = cur
					if cur <= 1 then
						time_speed.var = cur / 4
					else
						time_speed.var = 0.25 + (cur - 1) / 42.66
					end
					if cur <= 0 then
						symbol.symbol = Material("stormfox/symbols/time_pause.png")
					elseif cur < 1 then
						symbol.symbol = Material("stormfox/symbols/time_slow.png")
					elseif cur == 1 then
						symbol.symbol = Material("stormfox/symbols/time_default.png")
					elseif cur <= 11.7 then
						symbol.symbol = Material("stormfox/symbols/time_speedup.png")
					elseif cur <= 22.3 then
						symbol.symbol = Material("stormfox/symbols/time_speedup2.png")
					else
						symbol.symbol = Material("stormfox/symbols/time_speedup3.png")
					end
				end

			local blabel = vgui.Create("DLabel",panel)
				blabel.text = "Hold C"
				blabel:SetText("")
				blabel:SetSize(160,20)
			function blabel:Paint(w,h)
				local t = openChat and "Close chat to interact" or gui.IsConsoleVisible() and "Close console" or self.text
				surface.SetTextColor(colors[1])
				surface.SetFont("SkyFox-Console")
				local tw,th = surface.GetTextSize(t)
				surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2)
				surface.DrawText(t)
			end
			function panel:Think()
				if not self.enabled and input.IsKeyDown(KEY_C) and not openChat and not gui.IsConsoleVisible() then
					self.enabled = true
					self.btnClose:SetDisabled( false )
					self:MakePopup()
					self:SetSelected()
				elseif self.enabled and not input.IsKeyDown(KEY_C) then
					self.enabled = false
					self.btnClose:SetDisabled( true )
					self:SetMouseInputEnabled(false)
					self:SetKeyboardInputEnabled(false)
				end
			end
			blabel:SetPos(pw / 2 - 80,ph - 20)
			panel:SetPos((ScrW() / 4 ) * 3 - pw / 2,ScrH() / 6)
			--panel:MakePopup()
			panel.btnMaxim:SetVisible( false )
			panel.btnMinim:SetVisible( false )
			STORMFOX_WPANEL = panel
		end
	-- SF menu HUD
		concommand.Add("sf_menu",StormFox.OpenWeatherMenu)
		hook.Add("OnPlayerChat","StormFox - Menu",function(pl,text)
			if pl ~= LocalPlayer() then return end
			if text:lower() ~= "!sf menu" then return end
			StormFox.OpenWeatherMenu()
			return true
		end)
		list.Set( "DesktopWindows", "StormFox", {
			title		= "StormFox",
			icon		= "stormfox/SF.png",
			width		= 960,
			height		= 700,
			onewindow	= true,
			init		= function(icon)
				StormFox.OpenWeatherMenu()
				icon.Window:Remove()
				LocalPlayer():EmitSound("garrysmod/ui_click.wav")
			end
			})
	end