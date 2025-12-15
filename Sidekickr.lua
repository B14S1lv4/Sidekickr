-- Auto Companion Summoner
-- Summons a random companion every 15 minutes when stationary

local ACS = {}

-- List of companion spell names
ACS.companions = {
    "Baby Shark",
    "Blitzen",
    "Hawksbill Snapjaw",
    "Hadwig",
    "Loggerhead Snapjaw",
    "Moonkin Hatchling",
    "Olive Snapjaw",
    "Wally",
    "Webwood Hatchling",
    "Mini Krampus"
}

-- Configuration
ACS.MAIN_CHECK_INTERVAL = 15 * 60  -- 15 minutes in seconds
ACS.RETRY_CHECK_INTERVAL = 15      -- 15 seconds
ACS.STATIONARY_TIME = 1            -- 1 second to confirm stationary

-- State variables
ACS.lastX = nil
ACS.lastY = nil
ACS.lastCheckTime = 0
ACS.isRetryMode = false
ACS.stationaryStartTime = nil
ACS.currentCompanion = nil  -- Track currently summoned companion
ACS.pendingCompanion = nil  -- Companion waiting to be summoned on next target change

-- Frame for events and updates
local frame = CreateFrame("Frame")

-- Scan spellbook for companion spells
function ACS:ScanSpellbook()
    self.companions = {}
    
    -- Get the number of spell tabs
    local numTabs = GetNumSpellTabs()
    
    -- Find the companion tab by name
    local companionTab = nil
    for tab = 1, numTabs do
        local tabName, texture, offset, numSpells = GetSpellTabInfo(tab)
        
        -- Check if this is the companion tab (case insensitive)
        if tabName then
            local lowerName = string.lower(tabName)
            -- Look for "companion", "pet", "minion" etc.
            if string.find(lowerName, "companion") or 
               string.find(lowerName, "pet") or
               string.find(lowerName, "minion") then
                companionTab = tab
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Found companion tab: " .. tabName)
                break
            end
        end
    end
    
    if not companionTab then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Sidekickr]|r Warning: Could not find companion tab!")
        return 0
    end
    
    -- Scan all spells in the companion tab
    local tabName, texture, offset, numSpells = GetSpellTabInfo(companionTab)
    
    for i = 1, numSpells do
        local spellIndex = offset + i
        local spellName, spellRank = GetSpellName(spellIndex, BOOKTYPE_SPELL)
        
        if spellName then
            -- Add all spells from the companion tab
            table.insert(self.companions, spellName)
        end
    end
    
    return table.getn(self.companions)
end

-- Check if player is in an instance
function ACS:IsInInstance()
    -- Check if player is in an instance/raid/battleground
    -- In Classic WoW, we can check the minimap zone text or use a workaround
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        return true
    end
    return false
end

-- Check if player can summon (not in combat, not in instance)
function ACS:CanSummon()
    if UnitAffectingCombat("player") then
        return false
    end
    
    if self:IsInInstance() then
        return false
    end
    
    return true
end

-- Check if player is stationary
function ACS:IsStationary()
    local x, y = GetPlayerMapPosition("player")
    
    -- First check or player moved
    if self.lastX == nil or self.lastY == nil then
        self.lastX = x
        self.lastY = y
        self.stationaryStartTime = GetTime()
        return false
    end
    
    -- Check if position changed
    if math.abs(x - self.lastX) > 0.0001 or math.abs(y - self.lastY) > 0.0001 then
        self.lastX = x
        self.lastY = y
        self.stationaryStartTime = GetTime()
        return false
    end
    
    -- Check if stationary for required time
    local stationaryDuration = GetTime() - self.stationaryStartTime
    return stationaryDuration >= self.STATIONARY_TIME
end

-- Summon a random companion
function ACS:SummonRandomCompanion()
    -- Summoning a new companion automatically dismisses the old one
    -- BUT if we summon the same one, it dismisses it instead!
    -- So we need to pick a different companion than the current one
    
    local availableCompanions = {}
    for _, companionName in ipairs(self.companions) do
        if companionName ~= self.currentCompanion then
            table.insert(availableCompanions, companionName)
        end
    end
    
    -- If no available companions (shouldn't happen with 9 companions), use all
    if table.getn(availableCompanions) == 0 then
        availableCompanions = self.companions
    end
    
    local randomIndex = math.random(1, table.getn(availableCompanions))
    local companionName = availableCompanions[randomIndex]
    
    -- Can't cast directly - requires hardware event
    -- Set pending companion to be cast on next target change
    self.pendingCompanion = companionName
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Ready to summon: " .. companionName .. " (change targets to cast)")
end

-- Actually cast the pending companion (called from hardware event)
function ACS:CastPendingCompanion()
    if not self.pendingCompanion then
        return
    end
    
    local companionName = self.pendingCompanion
    CastSpellByName(companionName)
    
    -- Update current companion
    self.currentCompanion = companionName
    self.pendingCompanion = nil
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Summoned: " .. companionName)
end

-- Main check function
function ACS:DoCheck()
    -- Check if we can summon
    if not self:CanSummon() then
        -- Enter retry mode
        if not self.isRetryMode then
            self.isRetryMode = true
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Sidekickr]|r Conditions not met, will retry every 15 seconds...")
        end
        return false
    end
    
    -- Check if stationary
    if not self:IsStationary() then
        -- Enter retry mode
        if not self.isRetryMode then
            self.isRetryMode = true
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Sidekickr]|r Not stationary, will retry every 15 seconds...")
        end
        return false
    end
    
    -- All conditions met, summon!
    self:SummonRandomCompanion()
    
    -- Reset to main timer
    self.isRetryMode = false
    self.lastCheckTime = GetTime()
    return true
end

-- OnUpdate handler
local timeSinceLastUpdate = 0
frame:SetScript("OnUpdate", function()
    timeSinceLastUpdate = timeSinceLastUpdate + arg1
    
    -- Determine which interval to use
    local checkInterval = ACS.isRetryMode and ACS.RETRY_CHECK_INTERVAL or ACS.MAIN_CHECK_INTERVAL
    
    -- Check if it's time to do a check
    if timeSinceLastUpdate >= 1 then  -- Check every second for position updates
        timeSinceLastUpdate = 0
        
        local currentTime = GetTime()
        if currentTime - ACS.lastCheckTime >= checkInterval then
            ACS.lastCheckTime = currentTime
            ACS:DoCheck()
        end
    end
end)

-- Initialize
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        ACS.lastCheckTime = GetTime()
        ACS.lastX = nil
        ACS.lastY = nil
        ACS.stationaryStartTime = GetTime()
        
        -- Scan spellbook for companions
        local numFound = ACS:ScanSpellbook()
        
        if numFound > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Loaded! Found " .. numFound .. " companions. Will check every 15 minutes.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Sidekickr]|r Warning: No companion spells found in spellbook!")
        end
        
        -- Seed random number generator
        math.randomseed(GetTime())
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Cast pending companion when player changes target (hardware event)
        ACS:CastPendingCompanion()
    end
end)

-- Slash command for manual testing
SLASH_AUTOCOMPANION1 = "/acs"
SLASH_AUTOCOMPANION2 = "/autocompanion"
SlashCmdList["AUTOCOMPANION"] = function(msg)
    if msg == "summon" or msg == "test" then
        ACS:SummonRandomCompanion()
    elseif msg == "scan" then
        local numFound = ACS:ScanSpellbook()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Found " .. numFound .. " companion spells:")
        for i, name in ipairs(ACS.companions) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. name)
        end
    elseif msg == "check" then
        local canSummon = ACS:CanSummon()
        local isStationary = ACS:IsStationary()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Status:")
        DEFAULT_CHAT_FRAME:AddMessage("  Can Summon: " .. tostring(canSummon))
        DEFAULT_CHAT_FRAME:AddMessage("  Is Stationary: " .. tostring(isStationary))
        DEFAULT_CHAT_FRAME:AddMessage("  Retry Mode: " .. tostring(ACS.isRetryMode))
    elseif msg == "reset" then
        ACS.lastCheckTime = GetTime() - ACS.MAIN_CHECK_INTERVAL
        ACS.isRetryMode = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Timer reset!")

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs summon - Manually summon a random companion")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs scan - Scan spellbook and list found companions")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs check - Check current status")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs reset - Reset the 15-minute timer")
    end
end
