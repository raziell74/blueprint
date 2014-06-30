-----------------------------------------------------------------------------------------------
-- Client Lua Script for Blueprint
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- Blueprint Module Definition
-----------------------------------------------------------------------------------------------
local Blueprint = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Blueprint:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function Blueprint:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- Blueprint OnLoad
-----------------------------------------------------------------------------------------------
function Blueprint:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Blueprint.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- Blueprint OnDocLoaded
-----------------------------------------------------------------------------------------------
function Blueprint:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "BlueprintForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("blueprint", "OnBlueprintOn", self)


		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- Blueprint Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/blueprint"
function Blueprint:OnBlueprintOn()
	self.wndMain:Invoke() -- show the window
end


-----------------------------------------------------------------------------------------------
-- BlueprintForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function Blueprint:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function Blueprint:OnCancel()
	self.wndMain:Close() -- hide the window
end


-----------------------------------------------------------------------------------------------
-- Blueprint Instance
-----------------------------------------------------------------------------------------------
local BlueprintInst = Blueprint:new()
BlueprintInst:Init()
