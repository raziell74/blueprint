-----------------------------------------------------------------------------------------------
-- Client Lua Script for Blueprint
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "HousingLib"
 
-----------------------------------------------------------------------------------------------
-- Blueprint Module Definition
-----------------------------------------------------------------------------------------------
local Blueprint = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local knTimerDelay = 1.0
local knTimerDelayShort = 0.25
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Blueprint:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
    o.bluePrints = {}

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
-- Blueprint OnSave
-----------------------------------------------------------------------------------------------
function Blueprint:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
            return
	end

	return self.bluePrints
end

-----------------------------------------------------------------------------------------------
-- Blueprint OnRestore
-----------------------------------------------------------------------------------------------
function Blueprint:OnRestore(eType, bluePrints)
	if bluePrints then
	    self.bluePrints = bluePrints
	end
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
                
                self.wndNewSet   = Apollo.LoadForm(self.xmlDoc, "CreateDecorSetForm", nil, self)
                self.wndCopySet  = Apollo.LoadForm(self.xmlDoc, "CopySetForm", nil, self)
                self.wndLoadSet  = Apollo.LoadForm(self.xmlDoc, "LoadSetForm", nil, self)
                self.wndPlaceAll = Apollo.LoadForm(self.xmlDoc, "PlaceAllForm", nil, self)
                self.wndDeleteSetBtn = self.wndMain:FindChild("DeleteSetBtn")
		
                self.wndMain:Show(false, true)
                self.wndNewSet:Show(false, true)
		self.wndCopySet:Show(false, true)
		self.wndLoadSet:Show(false, true)
		self.wndPlaceAll:Show(false, true)
                
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("blueprint", "OnBlueprintOn", self)
                
                --create object shortcuts to commonly used elements
                self.blueprintList = self.wndMain:FindChild("BlueprintList")
                self.decorList     = self.wndMain:FindChild("DecorList")
                
                self.bPlayerIsInside = false;
                
                Apollo.RegisterEventHandler("HousingPanelControlOpen", "OnPropertyEnter", self)
                Apollo.RegisterEventHandler("HousingPanelControlClose", "OnPropertyExit", self)
                
                self:OnBlueprintOn()
	end
end

-----------------------------------------------------------------------------------------------
-- Blueprint Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/blueprint" or on shortcut button click
function Blueprint:OnBlueprintOn()
    -- show the window
    self.wndMain:Invoke()
    self.wndMain:ToFront()
    
    -- Populate blueprint lists
    self.blueprintList:DeleteAll()
    self.blueprintList:AddRow("Current", "", "Current")
    local mycounter = 1
    for key,value in pairs(self.bluePrints) do 
        self.blueprintList:AddRow(value.name, "", value.name)
        mycounter = mycounter + 1
    end
    
    -- select the current decor list by default
    self.blueprintList:SetCurrentRow(1)
    self.wndDeleteSetBtn:Enable(false)
    
    -- populate the decor list with the current set
    local decorList = self:getCurrentDecor()
    self:populateDecorList(decorList)
    
    SendVarToRover("Saved Data", self.bluePrints)
end

--
-- Populates the decor list form UI element with the names of the decor items given as a param (array)
--
function Blueprint:populateDecorList(decorList)
    local rowText = ""
    local decorInfo
    
    -- clear all the current rows
    self.decorList:DeleteAll()
    
    -- add each decor item with additional information
    for idx = 1, #decorList do
        decorInfo = decorList[idx]
        rowText   = decorInfo.strName
        
        -- Prepend a placement flag if the decor item has been placed
        if decorInfo.placed then
            rowText = "PLACED -- " .. rowText
        else
            rowText = "                    " .. rowText
        end
        
        -- append weather the item is exterior or interior
        if decorInfo.isInterior then
            rowText = rowText .. " [Interior]"
        else
            rowText = rowText .. " [Exterior]"
        end
        
        -- add the item to the decor listing
        self.decorList:AddRow(rowText)
    end
end

--
-- Gathers data on the currently placed decor items. Returns an array of these objects
-- This will also determine if the items are inside the house or outside as well as if they have already been placed or not
--
function Blueprint:getCurrentDecor()
    local decorList  = HousingLib.GetPlacedDecorList()
    local ItemHandle = 0
    local decorObject
    local decorInfo
    local finalList = {}
    
    if decorList ~= nil then
        local DecorCount = 1
        for idx = 1, #decorList do
                -- make sure we always disable the free placement before previewing placed decor
                if ItemHandle ~= 0 then
                    HousingLib.FreePlaceDecorDisplacement_Cancel(ItemHandle)
                end
                
                -- grab the info on the decor object
                decorObject = decorList[idx]
                ItemHandle  = HousingLib.PreviewPlacedDecor(decorObject.nDecorId, decorObject.nDecorIdHi)
                decorInfo   = HousingLib.GetDecorIconInfo(ItemHandle)
                
                -- turn decor previewing off since we have our data now
                if ItemHandle ~= 0 then
                    HousingLib.FreePlaceDecorDisplacement_Cancel(ItemHandle)
                end
                
                -- has our item already bene placed?
                decorInfo.placed   = self:IsDecorPlaced(decorInfo)
                
                -- determines of the decor item is inside the house or not
                if decorInfo.fWorldPosY < -80 then
                    decorInfo.isInterior = true
                elseif decorInfo.fWorldPosY >= -80 then
                    decorInfo.isInterior = false
                end
                
                -- Insert the updated data object into the returnable list
                table.insert(finalList, decorInfo)
        end
    end
    
    -- return our final list
    return finalList
end

--
-- Rechecks a list of decor items to see if they have been placed yet or not
--
function Blueprint:updatePlacement(decorList)
    local decorInfo
    local finalList = {}
    
    if decorList ~= nil then
        for key, decorInfo in pairs(decorList) do
                -- has our item already bene placed?
                decorInfo.placed   = self:IsDecorPlaced(decorInfo)
                
                -- Insert the updated data object into the returnable list
                table.insert(finalList, decorInfo)
        end
    end
    
    -- return our final list
    return finalList
end

-- checks for if the item is currently placed or not
function Blueprint:IsDecorPlaced(confirmInfo)
    local decorList  = HousingLib.GetPlacedDecorList()
    local ItemHandle = 0
    local decorObject
    local decorInfo
    
    SendVarToRover("Original " .. confirmInfo.strName, confirmInfo)
    
    SendVarToRover("decorList " .. confirmInfo.strName, decorList)
    
    if decorList ~= nil then
        for idx = 1, #decorList do
                if ItemHandle ~= 0 then
                    HousingLib.FreePlaceDecorDisplacement_Cancel(ItemHandle)
                end
                
                decorObject        = decorList[idx]
                ItemHandle         = HousingLib.PreviewPlacedDecor(decorObject.nDecorId, decorObject.nDecorIdHi)
                decorInfo          = HousingLib.GetDecorIconInfo(ItemHandle)
                decorListingString = decorInfo.strName
                
                if ItemHandle ~= 0 then
                    HousingLib.FreePlaceDecorDisplacement_Cancel(ItemHandle)
                end
                
                SendVarToRover("Checking " .. decorInfo.strName, decorInfo)
                
                -- check agaisnt all known placement values to see if an exact duplicate already exists in that space
                if  confirmInfo.fWorldPosX                == decorInfo.fWorldPosX and
                    math.floor(confirmInfo.fWorldPosY)    == math.floor(decorInfo.fWorldPosY) and
                    confirmInfo.fWorldPosZ                == decorInfo.fWorldPosZ and
                    confirmInfo.fPitch                    == decorInfo.fPitch and
                    confirmInfo.fRoll                     == decorInfo.fRoll and
                    math.floor(confirmInfo.fScaleCurrent) == math.floor(decorInfo.fScaleCurrent) and
                    math.floor(confirmInfo.fYaw)          == math.floor(decorInfo.fYaw) and
                    confirmInfo.strName                   == decorInfo.strName
                then
                    return true
                end
        end
    end
    
    return false
end

--
-- Set weather or not the player is on their property or not
--
function Blueprint:OnPropertyEnter(idPropertyInfo, idZone, bPlayerIsInside)
	if HousingLib.IsHousingWorld() then
	    self.bOnProperty     = true
            self.bPlayerIsInside = bPlayerIsInside == true --make sure we get true/false
	end
        --SendVarToRover("playerinside", self.bPlayerIsInside);
end

--
-- leaving property
--
function Blueprint:OnPropertyExit()
	self.bOnProperty = false -- you've left your property!
	self:OnCancel()
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

function Blueprint:OnOpenCreateNewSetWindow(wndHandler, wndControl)
	self.wndNewSet:Show(true, true)
	self.wndNewSet:ToFront()
	
        local wndSettingsFrame = self.wndNewSet:FindChild("SettingsFrame")
	wndSettingsFrame:SetRadioSel("IncludeDecorRadioGroup", 1)
        
        -- Default the name of the set
        local currentRow = self.blueprintList:GetCurrentRow()
        local strDefaultName = "New Blueprint"
        local wndSettingsFrame = self.wndNewSet:FindChild("SettingsFrame")
        local wndNameEntry = wndSettingsFrame:FindChild("NewNameEntry")
        local wndTitle = wndSettingsFrame:FindChild("BG_ArtHeader")
            
	if currentRow ~= nil and currentRow ~= 1 then
	    local currentBlueprint = self.blueprintList:GetCellData( currentRow, 1 )            
            strDefaultName = currentBlueprint
        end
        
        wndNameEntry:SetText(strDefaultName)
        
end

function Blueprint:OnCloseCreateNewDecorSetWindow()
	self.wndNewSet:Show(false, true)
end

-- BLUE PRINT CREATION

function Blueprint:OnCreateNewSetBtn(wndHandler, wndControl)
    -- Get form settings
    local wndSettingsFrame = self.wndNewSet:FindChild("SettingsFrame")
    local wndNameEntry     = wndSettingsFrame:FindChild("NewNameEntry")
    local nSaveOptions     = wndSettingsFrame:GetRadioSel("IncludeDecorRadioGroup")
    
    -- default the blueprint name if it's not set
    local strName = wndNameEntry:GetText()
    if strName == nil or strName == "" then
        local numberOfSavedSets = #self.bluePrints
        strName = "New Blueprint"
    end
    
    -- set up the blueprint for saving
    local bluePrint = {}
    bluePrint.name = strName
    bluePrint.decor = {}
    
    -- Add the current decor to the bluePrint listing
    local decorList = self:getCurrentDecor()
    if decorList ~= nil then
        for idx = 1, #decorList do
            decorInfo = decorList[idx]
            
            -- Check agaisnt our decor settings for what to save (all => 1, interior_only => 2, exterior_only => 3)
            if nSaveOptions == 1 then -- saves all decor
                table.insert(bluePrint.decor, decorInfo)
            elseif (nSaveOptions == 2) and (decorInfo.isInterior) then --saves only interior decor
                table.insert(bluePrint.decor, decorInfo)
            elseif (nSaveOptions == 3) and (decorInfo.isInterior == false) then --saves only exterior decor
                table.insert(bluePrint.decor, decorInfo)
            end
        end
    end
    
    -- Insert the blueprint into our saved data
    self.bluePrints[bluePrint.name] = bluePrint
    
    self:OnBlueprintOn()
    
    self.wndNewSet:Show(false, true)
end

function Blueprint:OnCancelCreateBtn()
	self.wndNewSet:Show(false, true)
end

-- BLUE PRINT DELETION

function Blueprint:OnDeleteSetBtn(wndHandler, wndControl)
	local currentRow = self.blueprintList:GetCurrentRow()
	if currentRow ~= nil and currentRow ~= 1 then
	    local currentBlueprint = self.blueprintList:GetCellData( currentRow, 1 )
	    self.bluePrints[currentBlueprint] = nil
	end
	
	self:OnBlueprintOn()
end

-- Decor Set Listing changes

function Blueprint:OnBlueprintListItemChange(wndControl, wndHandler, nX, nY)
	-- Preview the selected item
	local currentRow = self.blueprintList:GetCurrentRow()
	if currentRow ~= nil and currentRow ~= 1 then
	    local currentBlueprint = self.blueprintList:GetCellData( currentRow, 1 )
	    
            -- populate the decor list with the current set
            local blueprint = self.bluePrints[currentBlueprint]
            local decor = self:updatePlacement(blueprint.decor)
            SendVarToRover("blueprints decorlist", decor)
            self:populateDecorList(decor)
            
	    self.wndDeleteSetBtn:Enable(true)
        elseif currentRow == 1 then
            self:OnBlueprintOn()
	end
end

-----------------------------------------------------------------------------------------------
-- Blueprint Instance
-----------------------------------------------------------------------------------------------
local BlueprintInst = Blueprint:new()
BlueprintInst:Init()
