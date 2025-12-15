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

-- Frame for events and updates
local frame = CreateFrame("Frame")

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

-- Dismiss current companion
function ACS:DismissCompanion()
    -- In Classic WoW, companions are dismissed by right-clicking the buff
    -- We need to iterate through buffs and find the companion
    local i = 1
    while UnitBuff("player", i) do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        -- Check if this buff is from one of our companions
        for _, companionName in ipairs(self.companions) do
            if name == companionName then
                CancelPlayerBuff(i - 1)  -- CancelPlayerBuff uses 0-based index
                return true
            end
        end
        i = i + 1
    end
    return false
end

-- Summon a random companion
function ACS:SummonRandomCompanion()
    -- Dismiss current companion first
    self:DismissCompanion()
    
    -- Wait a brief moment for dismissal to process
    -- Then summon new companion
    local randomIndex = math.random(1, table.getn(self.companions))
    local companionName = self.companions[randomIndex]
    
    -- Use CallCompanion or CastSpellByName depending on how companions work
    CastSpellByName(companionName)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto Companion]|r Summoned: " .. companionName)
end

-- Main check function
function ACS:DoCheck()
    -- Check if we can summon
    if not self:CanSummon() then
        -- Enter retry mode
        if not self.isRetryMode then
            self.isRetryMode = true
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Auto Companion]|r Conditions not met, will retry every 15 seconds...")
        end
        return false
    end
    
    -- Check if stationary
    if not self:IsStationary() then
        -- Enter retry mode
        if not self.isRetryMode then
            self.isRetryMode = true
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Auto Companion]|r Not stationary, will retry every 15 seconds...")
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
frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        ACS.lastCheckTime = GetTime()
        ACS.lastX = nil
        ACS.lastY = nil
        ACS.stationaryStartTime = GetTime()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto Companion Summoner]|r Loaded! Will check every 15 minutes.")
        
        -- Seed random number generator
        math.randomseed(GetTime())
    end
end)

-- Slash command for manual testing
SLASH_AUTOCOMPANION1 = "/acs"
SLASH_AUTOCOMPANION2 = "/autocompanion"
SlashCmdList["AUTOCOMPANION"] = function(msg)
    if msg == "summon" or msg == "test" then
        ACS:SummonRandomCompanion()
    elseif msg == "check" then
        local canSummon = ACS:CanSummon()
        local isStationary = ACS:IsStationary()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto Companion]|r Status:")
        DEFAULT_CHAT_FRAME:AddMessage("  Can Summon: " .. tostring(canSummon))
        DEFAULT_CHAT_FRAME:AddMessage("  Is Stationary: " .. tostring(isStationary))
        DEFAULT_CHAT_FRAME:AddMessage("  Retry Mode: " .. tostring(ACS.isRetryMode))
    elseif msg == "reset" then
        ACS.lastCheckTime = GetTime() - ACS.MAIN_CHECK_INTERVAL
        ACS.isRetryMode = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto Companion]|r Timer reset!")
    elseif msg == "dismiss" then
        ACS:DismissCompanion()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto Companion]|r Companion dismissed!")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto Companion Summoner]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs summon - Manually summon a random companion")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs check - Check current status")
        DEFAULT_CHAT_FRAME:AddMessage("  /acs reset - Reset the 15-minute timer")
    end
end
