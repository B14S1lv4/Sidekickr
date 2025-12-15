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
ACS.DEFAULT_WEIGHT = 1             -- Default weight for new companions

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
                ACS.companionTabIndex = tab
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
            
            -- Initialize weight if not set
            if not SidekickrWeights then
                SidekickrWeights = {}
            end
            if not SidekickrWeights[spellName] then
                SidekickrWeights[spellName] = self.DEFAULT_WEIGHT
            end
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

-- Weighted random selection
function ACS:PickWeightedCompanion(excludeName)
    local availableCompanions = {}
    local totalWeight = 0
    
    -- Build list of available companions with their weights
    for _, companionName in ipairs(self.companions) do
        if companionName ~= excludeName then
            local weight = SidekickrWeights[companionName] or self.DEFAULT_WEIGHT
            if weight > 0 then  -- Only include companions with positive weight
                table.insert(availableCompanions, {name = companionName, weight = weight})
                totalWeight = totalWeight + weight
            end
        end
    end
    
    -- If no available companions, use all with equal weight
    if table.getn(availableCompanions) == 0 then
        for _, companionName in ipairs(self.companions) do
            table.insert(availableCompanions, {name = companionName, weight = 1})
            totalWeight = totalWeight + 1
        end
    end
    
    -- Weighted random selection
    local roll = math.random() * totalWeight
    local cumulative = 0
    
    for _, companion in ipairs(availableCompanions) do
        cumulative = cumulative + companion.weight
        if roll <= cumulative then
            return companion.name
        end
    end
    
    -- Fallback (shouldn't happen)
    return availableCompanions[1].name
end

-- Summon a random companion
function ACS:SummonRandomCompanion(force)
    -- Use weighted random selection, excluding current companion
    local companionName = self:PickWeightedCompanion(self.currentCompanion)
    
    -- Can't cast directly - requires hardware event
    -- Set pending companion to be cast on next target change
    self.pendingCompanion = companionName

    if force then
        -- If forced, cast immediately (for testing)
        self:CastPendingCompanion()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Summon: " .. companionName .. " (forced)")
        return
    end
    
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
    self:SummonRandomCompanion(false)
    
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

-- Set weight for a companion
function ACS:SetWeight(companionName, weight)
    -- Find companion by partial name match
    local matches = {}
    for _, name in ipairs(self.companions) do
        if string.find(string.lower(name), string.lower(companionName)) then
            table.insert(matches, name)
        end
    end
    
    if table.getn(matches) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Sidekickr]|r No companion found matching: " .. companionName)
        return false
    elseif table.getn(matches) > 1 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Sidekickr]|r Multiple companions match. Please be more specific:")
        for _, name in ipairs(matches) do
            DEFAULT_CHAT_FRAME:AddMessage("  - " .. name)
        end
        return false
    end
    
    local fullName = matches[1]
    SidekickrWeights[fullName] = weight
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Set weight for " .. fullName .. " to " .. string.format("%.1f", weight))
    self:UpdateSpellbookOverlays()
    return true
end

-- Hook spellbook to show weights
function ACS:HookSpellbook()
    -- Hook the spellbook button updates
    local oldSpellButton_UpdateButton = SpellButton_UpdateButton
    SpellButton_UpdateButton = function()
        oldSpellButton_UpdateButton()
        ACS:UpdateSpellbookOverlays()
    end
end

function ACS:UpdateSpellbookOverlays()
    if not SpellBookFrame:IsVisible() then
        return
    end
    
    -- Check if we're on the companion tab
    local currentTab = SpellFrame_GetCurrentPage and SpellFrame_GetCurrentPage() or 1
    
    for i = 1, SPELLS_PER_PAGE do
        local button = getglobal("SpellButton"..i)
        if button and button:IsVisible() then
            local spellIndex = SpellBook_GetSpellID(i)
            local spellName = GetSpellName(spellIndex, BOOKTYPE_SPELL)
            
            if spellName and SidekickrWeights[spellName] then
                -- Create or update weight text
                local weightText = getglobal("SpellButton"..i.."SidekickrWeight")
                if not weightText then
                    weightText = button:CreateFontString("SpellButton"..i.."SidekickrWeight", "OVERLAY", "NumberFontNormalLarge")
                    weightText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
                end
                
                local weight = SidekickrWeights[spellName]
                weightText:SetText(string.format("%.1f", weight))
                
                -- Color based on weight
                if weight == 0 then
                    weightText:SetTextColor(1, 0, 0)  -- Red for disabled
                elseif weight < 1 then
                    weightText:SetTextColor(1, 1, 0)  -- Yellow for low
                elseif weight > 1 then
                    weightText:SetTextColor(0, 1, 0)  -- Green for high
                else
                    weightText:SetTextColor(1, 1, 1)  -- White for default
                end
                
                weightText:Show()
            else
                -- Hide weight text for non-companion spells
                local weightText = getglobal("SpellButton"..i.."SidekickrWeight")
                if weightText then
                    weightText:Hide()
                end
            end
        end
    end
end

-- Initialize
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("SPELLBOOK_UPDATE")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        ACS.lastCheckTime = GetTime()
        ACS.lastX = nil
        ACS.lastY = nil
        ACS.stationaryStartTime = GetTime()
        
        -- Initialize saved variables
        if not SidekickrWeights then
            SidekickrWeights = {}
        end
        
        -- Scan spellbook for companions
        local numFound = ACS:ScanSpellbook()
        
        if numFound > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Loaded! Found " .. numFound .. " companions. Will check every 15 minutes.")
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Use /acs scan to see companions, /acs set <name> <weight> to adjust.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Sidekickr]|r Warning: No companion spells found in spellbook!")
        end
        
        -- Hook spellbook
        ACS:HookSpellbook()
        
        -- Seed random number generator
        math.randomseed(GetTime())
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Cast pending companion when player changes target (hardware event)
        ACS:CastPendingCompanion()
    elseif event == "SPELLBOOK_UPDATE" then
        ACS:UpdateSpellbookOverlays()
    end
end)

-- Slash command for manual testing
SLASH_AUTOCOMPANION1 = "/acs"
SLASH_AUTOCOMPANION2 = "/autocompanion"
SlashCmdList["AUTOCOMPANION"] = function(msg)
    if msg == "summon" or msg == "test" then
        ACS:SummonRandomCompanion(true)
    elseif msg == "queue" then
        ACS:SummonRandomCompanion(false)
    elseif msg == "scan" then
        local numFound = ACS:ScanSpellbook()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Sidekickr]|r Found " .. numFound .. " companion spells:")
        for i, name in ipairs(ACS.companions) do
            local weight = SidekickrWeights[name] or ACS.DEFAULT_WEIGHT
            DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. name .. " (weight: " .. string.format("%.1f", weight) .. ")")
        end
    elseif string.sub(msg, 1, 3) == "set" then
        -- Parse: /acs set <name> <weight>
        local _, _, name, weight = string.find(msg, "set%s+(.+)%s+([%d%.]+)")
        if name and weight then
            ACS:SetWeight(name, tonumber(weight))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Sidekickr]|r Usage: /acs set <companion name> <weight>")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Sidekickr]|r Example: /acs set shark 2.5")
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
        DEFAULT_CHAT_FRAME:AddMessage("  /acs queue - Queue companion to summon on next target change")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs scan - Scan spellbook and list found companions")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs set <name> <weight> - Set companion weight (0-10)")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs check - Check current status")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs reset - Reset the 15-minute timer")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF888888[Sidekickr]|r Example: /acs set shark 2.5")
    end
end
