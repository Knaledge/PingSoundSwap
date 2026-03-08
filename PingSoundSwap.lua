local PingSoundSwap = {};
PingSoundSwap.frame = CreateFrame("Frame");
PingSoundSwap.isPingHooked = false;
PingSoundSwap.settingsRegistered = false;
PingSoundSwap.categoryID = nil;
PingSoundSwap.activeProfile = nil;
PingSoundSwap.activeProfileKey = nil;
PingSoundSwap.soundOptionData = nil;
PingSoundSwap.soundIndex = nil;
PingSoundSwap.soundBucketKeys = nil;
PingSoundSwap.soundOptionsByBucket = nil;
PingSoundSwap.lastPlayedAt = {};
PingSoundSwap.isPinStyleHooked = false;

local DB_VERSION = 1;
local PREFIX = "|cff4dc3ffPingSoundSwap:|r ";

local PROFILE_MODES = {
    character = true,
    realm = true,
    account = true,
    custom = true,
};

local PING_TYPES = {
    "Attack",
    "Warning",
    "Assist",
    "OnMyWay",
};

local PING_TYPE_SET = {
    Attack = true,
    Warning = true,
    Assist = true,
    OnMyWay = true,
};

local TEXTUREKIT_TO_PING = {
    Attack = "Attack",
    Warning = "Warning",
    Assist = "Assist",
    OnMyWay = "OnMyWay",
};

local ENUM_TO_PING = {};
if Enum and Enum.PingSubjectType then
    ENUM_TO_PING[Enum.PingSubjectType.Attack] = "Attack";
    ENUM_TO_PING[Enum.PingSubjectType.Warning] = "Warning";
    ENUM_TO_PING[Enum.PingSubjectType.Assist] = "Assist";
    ENUM_TO_PING[Enum.PingSubjectType.OnMyWay] = "OnMyWay";
end

local function IsValidPingType(pingType)
    return PING_TYPE_SET[pingType] == true;
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg));
end

function PingSoundSwap:IsDebugEnabled()
    return self.db and self.db.debug == true;
end

function PingSoundSwap:Debug(msg)
    if self:IsDebugEnabled() then
        Print("[debug] " .. tostring(msg));
    end
end

local function SK(name, fallback)
    if SOUNDKIT and type(SOUNDKIT[name]) == "number" then
        return SOUNDKIT[name];
    end
    return fallback;
end

local CURATED_SOUND_OPTIONS = {
    { name = "MAP_PING", id = SK("MAP_PING", 3175), label = "Map Ping", tag = "Alert" },
    { name = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = SK("IG_MAINMENU_OPTION_CHECKBOX_ON", 856), label = "Checkbox On", tag = "UI" },
    { name = "IG_MAINMENU_OPTION_CHECKBOX_OFF", id = SK("IG_MAINMENU_OPTION_CHECKBOX_OFF", 857), label = "Checkbox Off", tag = "UI" },
    { name = "IG_MAINMENU_OPTION", id = SK("IG_MAINMENU_OPTION", 852), label = "Main Menu Option", tag = "UI" },
    { name = "IG_MAINMENU_OPEN", id = SK("IG_MAINMENU_OPEN", 850), label = "Main Menu Open", tag = "UI" },
    { name = "IG_MAINMENU_CLOSE", id = SK("IG_MAINMENU_CLOSE", 851), label = "Main Menu Close", tag = "UI" },
    { name = "UI_BONUS_EVENT_SYSTEM_VIGNETTESOUND", id = SK("UI_BONUS_EVENT_SYSTEM_VIGNETTESOUND", 12867), label = "Bonus Event Vignette", tag = "Alert" },
    { name = "UI_WORLDQUEST_START", id = SK("UI_WORLDQUEST_START", 73275), label = "World Quest Start", tag = "Quest" },
    { name = "UI_WORLDQUEST_MAP_SELECT", id = SK("UI_WORLDQUEST_MAP_SELECT", 73276), label = "World Quest Select", tag = "Quest" },
    { name = "UI_WORLDQUEST_COMPLETE", id = SK("UI_WORLDQUEST_COMPLETE", 73277), label = "World Quest Complete", tag = "Quest" },
    { name = "READY_CHECK", id = SK("READY_CHECK", 8960), label = "Ready Check", tag = "Alert" },
    { name = "RAID_WARNING", id = SK("RAID_WARNING", 8959), label = "Raid Warning", tag = "Alert" },
    { name = "UI_GROUP_FINDER_RECEIVE_APPLICATION", id = SK("UI_GROUP_FINDER_RECEIVE_APPLICATION", 38417), label = "Group Finder Invite", tag = "Alert" },
    { name = "UI_GROUP_FINDER_RECEIVE_APPLICATION_DECLINE", id = SK("UI_GROUP_FINDER_RECEIVE_APPLICATION_DECLINE", 38418), label = "Group Finder Decline", tag = "Alert" },
    { name = "UI_GARRISON_TOAST_INVASION_ALERT", id = SK("UI_GARRISON_TOAST_INVASION_ALERT", 10094), label = "Garrison Alert", tag = "Alert" },
    { name = "UI_SILVER_MISSION_COMPLETE_01", id = SK("UI_SILVER_MISSION_COMPLETE_01", 10218), label = "Mission Complete", tag = "UI" },
    { name = "UI_EPICLOOT_TOAST", id = SK("UI_EPICLOOT_TOAST", 31578), label = "Epic Loot Toast", tag = "UI" },
    { name = "ALARM_CLOCK_WARNING_3", id = SK("ALARM_CLOCK_WARNING_3", 18871), label = "Alarm Warning", tag = "Alert" },
    { name = "UI_IG_STORE_WINDOW_OPEN_BUTTON", id = SK("UI_IG_STORE_WINDOW_OPEN_BUTTON", 68816), label = "Store Button Open", tag = "UI" },
    { name = "PVP_THROUGH_QUEUE", id = SK("PVP_THROUGH_QUEUE", 8458), label = "PvP Through Queue", tag = "Combat" },
};

local function InferSoundTag(soundName)
    local upper = string.upper(soundName or "");
    if string.find(upper, "RAID") or string.find(upper, "WARNING") or string.find(upper, "READY") or string.find(upper, "ALARM") then
        return "Alert";
    elseif string.find(upper, "PVP") or string.find(upper, "COMBAT") or string.find(upper, "ARENA") or string.find(upper, "BATTLEGROUND") then
        return "Combat";
    elseif string.find(upper, "QUEST") then
        return "Quest";
    elseif string.find(upper, "UI_") or string.find(upper, "IG_") then
        return "UI";
    end
    return "Misc";
end

local function BuildSoundOptionLabel(soundID, soundName, categoryTag, isCurated, curatedLabel)
    local leadTag = isCurated and "[Curated]" or "[All]";
    local displayName = curatedLabel and curatedLabel ~= "" and curatedLabel or soundName;
    return string.format("%s[%s] %s (%d) - %s", leadTag, categoryTag, displayName, soundID, soundName);
end

local function BuildBucketLabel(bucketKey)
    if bucketKey == "curated" then
        return "Curated";
    elseif bucketKey == "other" then
        return "Other";
    elseif bucketKey == "digits" then
        return "0-9";
    end
    return string.upper(bucketKey);
end

local function GetBucketKeyForSoundName(soundName)
    local first = string.sub(string.upper(soundName or ""), 1, 1);
    if first == "" then
        return "other";
    elseif string.find(first, "%d") then
        return "digits";
    elseif string.find(first, "%a") then
        return string.lower(first);
    end
    return "other";
end

local DEFAULT_MAP_PING = SK("MAP_PING", 3175);
local DEFAULT_SOUNDS = {
    Attack = DEFAULT_MAP_PING,
    Warning = DEFAULT_MAP_PING,
    Assist = DEFAULT_MAP_PING,
    OnMyWay = DEFAULT_MAP_PING,
};

local function CopyDefaultSounds()
    return {
        Attack = DEFAULT_SOUNDS.Attack,
        Warning = DEFAULT_SOUNDS.Warning,
        Assist = DEFAULT_SOUNDS.Assist,
        OnMyWay = DEFAULT_SOUNDS.OnMyWay,
    };
end

local function CountTableKeys(t)
    local count = 0;
    for _ in pairs(t or {}) do
        count = count + 1;
    end
    return count;
end

local function NormalizeCustomKey(text)
    if type(text) ~= "string" then
        return "default";
    end

    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "");
    trimmed = trimmed:gsub("[%c]", "");
    if trimmed == "" then
        return "default";
    end

    return trimmed;
end

function PingSoundSwap:GetCharacterIdentity()
    local name, realm = UnitFullName("player");
    if not realm or realm == "" then
        realm = GetRealmName();
    end
    return name or "Unknown", realm or "UnknownRealm";
end

function PingSoundSwap:GetProfileKeyForMode(mode)
    local charName, realmName = self:GetCharacterIdentity();

    if mode == "character" then
        return string.format("char:%s-%s", charName, realmName);
    elseif mode == "realm" then
        return string.format("realm:%s", realmName);
    elseif mode == "account" then
        return "account:default";
    elseif mode == "custom" then
        local customKey = NormalizeCustomKey(PingSoundSwapCharDB.customProfileKey);
        return string.format("custom:%s", customKey);
    end

    return string.format("char:%s-%s", charName, realmName);
end

function PingSoundSwap:EnsureProfile(profileKey)
    if not self.db.profiles[profileKey] then
        self.db.profiles[profileKey] = {
            sounds = CopyDefaultSounds(),
        };
    end

    local profile = self.db.profiles[profileKey];
    profile.sounds = profile.sounds or {};

    for _, pingType in ipairs(PING_TYPES) do
        if type(profile.sounds[pingType]) ~= "number" then
            profile.sounds[pingType] = DEFAULT_SOUNDS[pingType];
        end
    end

    return profile;
end

function PingSoundSwap:InvalidateActiveProfileCache()
    self.activeProfile = nil;
    self.activeProfileKey = nil;
end

function PingSoundSwap:GetActiveMode()
    local mode = self.db.profileMode;
    if PROFILE_MODES[mode] then
        return mode;
    end
    self.db.profileMode = "character";
    return "character";
end

function PingSoundSwap:GetActiveProfileKey()
    return self:GetProfileKeyForMode(self:GetActiveMode());
end

function PingSoundSwap:GetActiveProfile()
    if self.activeProfile and self.activeProfileKey then
        return self.activeProfile, self.activeProfileKey;
    end

    local key = self:GetActiveProfileKey();
    local profile = self:EnsureProfile(key);
    self.activeProfile = profile;
    self.activeProfileKey = key;
    return profile, key;
end

function PingSoundSwap:SetProfileMode(mode)
    if not PROFILE_MODES[mode] then
        return false;
    end

    self.db.profileMode = mode;
    self:InvalidateActiveProfileCache();
    self:GetActiveProfile();
    return true;
end

function PingSoundSwap:SetCustomProfileKey(key)
    PingSoundSwapCharDB.customProfileKey = NormalizeCustomKey(key);
    self:InvalidateActiveProfileCache();
    if self:GetActiveMode() == "custom" then
        self:GetActiveProfile();
    end
end

function PingSoundSwap:GetSoundForPing(pingType)
    local profile = self:GetActiveProfile();
    return profile.sounds[pingType];
end

function PingSoundSwap:SetSoundForPing(pingType, soundID)
    if not IsValidPingType(pingType) then
        return false;
    end

    if type(soundID) ~= "number" or soundID <= 0 then
        return false;
    end

    local profile = self:GetActiveProfile();
    profile.sounds[pingType] = math.floor(soundID);
    return true;
end

function PingSoundSwap:PlaySoundMaster(soundID)
    if type(soundID) ~= "number" or soundID <= 0 then
        return false;
    end

    if C_Sound and C_Sound.PlaySound then
        local result = C_Sound.PlaySound(soundID, "Master");
        if type(result) == "table" then
            if result.success then
                return true;
            end
        elseif result then
            return true;
        end
    end

    local ok = PlaySound(soundID, "Master");
    return ok and true or false;
end

function PingSoundSwap:ApplyNativePingSuppression()
    if type(SetCVar) ~= "function" or type(GetCVar) ~= "function" then
        self:Debug("CVar API unavailable; cannot manage native ping sound suppression.");
        return;
    end

    local cvarName = "Sound_EnablePingSounds";
    local desired = self.db.suppressNativePingSounds and "0" or "1";
    local current = GetCVar(cvarName);
    if current ~= desired then
        SetCVar(cvarName, desired);
        self:Debug(string.format("Set CVar %s=%s", cvarName, desired));
    end
end

function PingSoundSwap:IsSoundInBucket(soundID, bucketKey)
    self:BuildSoundIndex();
    local entry = self.soundIndex[soundID];
    if not entry then
        return false;
    end

    if bucketKey == "curated" then
        return entry.curated == true;
    end

    return entry.bucket == bucketKey;
end

function PingSoundSwap:GetDefaultSoundForBucket(bucketKey)
    self:BuildSoundIndex();

    local candidate = nil;
    for _, entry in pairs(self.soundIndex) do
        local inBucket = (bucketKey == "curated" and entry.curated) or (bucketKey ~= "curated" and entry.bucket == bucketKey);
        if inBucket then
            if not candidate or entry.id < candidate then
                candidate = entry.id;
            end
        end
    end

    return candidate;
end

function PingSoundSwap:ExtractPingTypeFromArgs(...)
    local args = { ... };

    for i = 1, #args do
        local value = args[i];
        if type(value) == "string" then
            local pingType = TEXTUREKIT_TO_PING[value];
            if pingType then
                return pingType;
            end
        elseif type(value) == "number" then
            local pingType = ENUM_TO_PING[value];
            if pingType then
                return pingType;
            end
        elseif type(value) == "table" then
            local pingEnum = value.pingSubjectType or value.pingType;
            if type(pingEnum) == "number" then
                local pingType = ENUM_TO_PING[pingEnum];
                if pingType then
                    return pingType;
                end
            end
        end
    end

    return nil;
end

function PingSoundSwap:ShouldDebouncePing(pingType)
    local now = (type(GetTimePreciseSec) == "function") and GetTimePreciseSec() or GetTime();
    local last = self.lastPlayedAt[pingType];
    self.lastPlayedAt[pingType] = now;

    if last and (now - last) < 0.06 then
        return true;
    end

    return false;
end

function PingSoundSwap:PlayMappedPingSound(pingType, source)
    if not pingType then
        self:Debug(string.format("Ignored ping event from %s: could not resolve ping type", tostring(source)));
        return;
    end

    if self:ShouldDebouncePing(pingType) then
        self:Debug(string.format("Debounced ping type=%s source=%s", pingType, tostring(source)));
        return;
    end

    local soundID = self:GetSoundForPing(pingType);
    self:Debug(string.format("Ping type=%s source=%s soundID=%s", pingType, tostring(source), tostring(soundID)));
    if not self:PlaySoundMaster(soundID) then
        self:Debug(string.format("Failed to play soundID=%s for pingType=%s", tostring(soundID), tostring(pingType)));
    end
end

function PingSoundSwap:TryHookPingManager()
    if self.isPingHooked then
        self:Debug("TryHookPingManager skipped: already hooked.");
        return;
    end

    if type(PingManager) == "table" and type(PingManager.OnPingPinFrameAdded) == "function" then
        hooksecurefunc(PingManager, "OnPingPinFrameAdded", function(...)
            local pingType = PingSoundSwap:ExtractPingTypeFromArgs(...);
            PingSoundSwap:PlayMappedPingSound(pingType, "OnPingPinFrameAdded");
        end);

        if type(PingManager.OnPingAdded) == "function" then
            hooksecurefunc(PingManager, "OnPingAdded", function(...)
                local pingType = PingSoundSwap:ExtractPingTypeFromArgs(...);
                PingSoundSwap:PlayMappedPingSound(pingType, "OnPingAdded");
            end);
        end

        self.isPingHooked = true;
        Print("Ping hook active.");
        self:Debug("Hooked PingManager ping callbacks via hooksecurefunc.");
    else
        self:Debug("PingManager not ready; hook deferred.");
    end
end

function PingSoundSwap:TryHookPingPinStyle()
    if self.isPinStyleHooked then
        self:Debug("TryHookPingPinStyle skipped: already hooked.");
        return;
    end

    if type(PingPinFrameMixin) == "table" and type(PingPinFrameMixin.SetPinStyle) == "function" then
        hooksecurefunc(PingPinFrameMixin, "SetPinStyle", function(_, uiTextureKit, _isWorldPoint)
            local pingType = TEXTUREKIT_TO_PING[uiTextureKit];
            PingSoundSwap:PlayMappedPingSound(pingType, "PingPinFrameMixin:SetPinStyle");
        end);

        self.isPinStyleHooked = true;
        Print("Ping pin style hook active.");
        self:Debug("Hooked PingPinFrameMixin:SetPinStyle via hooksecurefunc.");
    else
        self:Debug("PingPinFrameMixin not ready; pin style hook deferred.");
    end
end

function PingSoundSwap:GetSoundOptionData()
    return self:GetSoundOptionDataForBucket("curated");
end

function PingSoundSwap:BuildSoundIndex()
    if self.soundIndex and self.soundBucketKeys and self.soundOptionsByBucket then
        return;
    end

    self.soundIndex = {};
    self.soundBucketKeys = { "curated", "digits" };
    self.soundOptionsByBucket = {};

    local seenBucketKey = {
        curated = true,
        digits = true,
    };

    local curatedByID = {};
    for _, option in ipairs(CURATED_SOUND_OPTIONS) do
        if type(option.id) == "number" and option.id > 0 and not curatedByID[option.id] then
            curatedByID[option.id] = option;
        end
    end

    for soundID, curated in pairs(curatedByID) do
        self.soundIndex[soundID] = {
            id = soundID,
            name = curated.name,
            label = curated.label,
            tag = curated.tag or InferSoundTag(curated.name),
            curated = true,
            bucket = "curated",
        };
    end

    if type(SOUNDKIT) == "table" then
        for soundName, soundID in pairs(SOUNDKIT) do
            if type(soundName) == "string" and type(soundID) == "number" and soundID > 0 and not self.soundIndex[soundID] then
                local bucketKey = GetBucketKeyForSoundName(soundName);
                self.soundIndex[soundID] = {
                    id = soundID,
                    name = soundName,
                    label = nil,
                    tag = InferSoundTag(soundName),
                    curated = false,
                    bucket = bucketKey,
                };

                if not seenBucketKey[bucketKey] then
                    seenBucketKey[bucketKey] = true;
                    table.insert(self.soundBucketKeys, bucketKey);
                end
            end
        end
    end

    table.sort(self.soundBucketKeys, function(a, b)
        local order = {
            curated = 1,
            digits = 2,
            other = 999,
        };
        local oa = order[a] or 100;
        local ob = order[b] or 100;
        if oa == ob then
            return a < b;
        end
        return oa < ob;
    end);

    self:Debug(string.format("Sound index built with %d entries and %d buckets", CountTableKeys(self.soundIndex), #self.soundBucketKeys));
end

function PingSoundSwap:GetSoundBucketOptionData()
    self:BuildSoundIndex();

    local container = Settings.CreateControlTextContainer();
    for _, bucketKey in ipairs(self.soundBucketKeys) do
        container:Add(bucketKey, BuildBucketLabel(bucketKey));
    end
    return container:GetData();
end

function PingSoundSwap:GetSoundOptionDataForBucket(bucketKey)
    self:BuildSoundIndex();
    bucketKey = bucketKey or "curated";

    if self.soundOptionsByBucket[bucketKey] then
        return self.soundOptionsByBucket[bucketKey];
    end

    local container = Settings.CreateControlTextContainer();
    local entries = {};

    for _, entry in pairs(self.soundIndex) do
        if bucketKey == "curated" then
            if entry.curated then
                table.insert(entries, entry);
            end
        elseif entry.bucket == bucketKey then
            table.insert(entries, entry);
        end
    end

    table.sort(entries, function(a, b)
        if a.curated ~= b.curated then
            return a.curated;
        end
        if a.id == b.id then
            return a.name < b.name;
        end
        return a.id < b.id;
    end);

    local maxOptions = (bucketKey == "curated") and #entries or math.min(#entries, 200);
    if maxOptions < #entries then
        self:Debug(string.format("Bucket %s trimmed from %d to %d entries for native dropdown stability", tostring(bucketKey), #entries, maxOptions));
    end

    for i = 1, maxOptions do
        local entry = entries[i];
        container:Add(entry.id, BuildSoundOptionLabel(entry.id, entry.name, entry.tag, entry.curated, entry.label));
    end

    self.soundOptionsByBucket[bucketKey] = container:GetData();
    return self.soundOptionsByBucket[bucketKey];
end

function PingSoundSwap:GetSoundBucketForPing(pingType)
    self:BuildSoundIndex();
    local bucketMap = self.db.soundBuckets or {};
    local bucket = bucketMap[pingType] or "curated";

    for _, key in ipairs(self.soundBucketKeys) do
        if key == bucket then
            return bucket;
        end
    end

    return "curated";
end

function PingSoundSwap:SetSoundBucketForPing(pingType, bucketKey)
    if not IsValidPingType(pingType) then
        return false;
    end

    self:BuildSoundIndex();

    local valid = false;
    for _, key in ipairs(self.soundBucketKeys) do
        if key == bucketKey then
            valid = true;
            break;
        end
    end

    if not valid then
        return false;
    end

    self.db.soundBuckets = self.db.soundBuckets or {};
    self.db.soundBuckets[pingType] = bucketKey;
    return true;
end

function PingSoundSwap:GetCustomProfileOptionData()
    local container = Settings.CreateControlTextContainer();
    local seen = {};

    container:Add("default", "default");
    seen["default"] = true;

    for profileKey in pairs(self.db.profiles) do
        local custom = profileKey:match("^custom:(.+)$");
        if custom and not seen[custom] then
            container:Add(custom, custom);
            seen[custom] = true;
        end
    end

    return container:GetData();
end

function PingSoundSwap:RegisterSettings()
    if self.settingsRegistered then
        return;
    end

    if not Settings or not Settings.RegisterVerticalLayoutCategory then
        return;
    end

    local category, _layout = Settings.RegisterVerticalLayoutCategory("PingSoundSwap");

    do
        local function GetValue()
            return PingSoundSwap.db.suppressNativePingSounds == true;
        end

        local function SetValue(value)
            PingSoundSwap.db.suppressNativePingSounds = value and true or false;
            PingSoundSwap:ApplyNativePingSuppression();
        end

        local setting = Settings.RegisterProxySetting(
            category,
            "PINGSOUNDSWAP_SUPPRESS_NATIVE",
            Settings.VarType.Boolean,
            "Suppress Native Ping Sounds",
            false,
            GetValue,
            SetValue
        );

        Settings.CreateCheckbox(category, setting, "When enabled, attempts to disable Blizzard's native ping sound so only your selected replacement is heard.");
    end

    do
        local function GetValue()
            return PingSoundSwap:GetActiveMode();
        end

        local function SetValue(value)
            PingSoundSwap:SetProfileMode(value);
        end

        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            container:Add("character", "Character");
            container:Add("realm", "Realm");
            container:Add("account", "Account");
            container:Add("custom", "Custom");
            return container:GetData();
        end

        local setting = Settings.RegisterProxySetting(
            category,
            "PINGSOUNDSWAP_PROFILE_MODE",
            Settings.VarType.String,
            "Profile Scope",
            "character",
            GetValue,
            SetValue
        );

        Settings.CreateDropdown(category, setting, GetOptions, "Choose how the active profile is selected.");
    end

    do
        local function GetValue()
            return NormalizeCustomKey(PingSoundSwapCharDB.customProfileKey);
        end

        local function SetValue(value)
            PingSoundSwap:SetCustomProfileKey(value);
        end

        local function GetOptions()
            return PingSoundSwap:GetCustomProfileOptionData();
        end

        local setting = Settings.RegisterProxySetting(
            category,
            "PINGSOUNDSWAP_CUSTOM_PROFILE",
            Settings.VarType.String,
            "Custom Profile Key",
            "default",
            GetValue,
            SetValue
        );

        Settings.CreateDropdown(category, setting, GetOptions, "Select a custom profile key. Use /pss custom <name> to create new keys.");
    end

    for _, pingType in ipairs(PING_TYPES) do
        do
            local bucketVariableName = "PINGSOUNDSWAP_BUCKET_" .. string.upper(pingType);
            local bucketLabel = string.format("%s Sound List", pingType);

            local function GetBucketValue()
                return PingSoundSwap:GetSoundBucketForPing(pingType);
            end

            local function SetBucketValue(value)
                if PingSoundSwap:SetSoundBucketForPing(pingType, value) then
                    local currentSoundID = PingSoundSwap:GetSoundForPing(pingType);
                    if not PingSoundSwap:IsSoundInBucket(currentSoundID, value) then
                        local fallbackSoundID = PingSoundSwap:GetDefaultSoundForBucket(value);
                        if fallbackSoundID then
                            PingSoundSwap:SetSoundForPing(pingType, fallbackSoundID);
                        end
                    end
                end
            end

            local function GetBucketOptions()
                return PingSoundSwap:GetSoundBucketOptionData();
            end

            local bucketSetting = Settings.RegisterProxySetting(
                category,
                bucketVariableName,
                Settings.VarType.String,
                bucketLabel,
                "curated",
                GetBucketValue,
                SetBucketValue
            );

            Settings.CreateDropdown(category, bucketSetting, GetBucketOptions, string.format("Choose which group of SOUNDKIT entries is shown for %s.", pingType));
        end

        local variableName = "PINGSOUNDSWAP_SOUND_" .. string.upper(pingType);
        local label = string.format("%s Ping Sound", pingType);

        local function GetValue()
            return PingSoundSwap:GetSoundForPing(pingType);
        end

        local function SetValue(value)
            PingSoundSwap:SetSoundForPing(pingType, value);
        end

        local function GetOptions()
            local bucketKey = PingSoundSwap:GetSoundBucketForPing(pingType);
            return PingSoundSwap:GetSoundOptionDataForBucket(bucketKey);
        end

        local setting = Settings.RegisterProxySetting(
            category,
            variableName,
            Settings.VarType.Number,
            label,
            DEFAULT_SOUNDS[pingType],
            GetValue,
            SetValue
        );

        Settings.CreateDropdown(category, setting, GetOptions, string.format("Choose a replacement sound for %s pings.", pingType));
    end

    Settings.RegisterAddOnCategory(category);
    self.categoryID = category:GetID();
    self.settingsRegistered = true;
end

function PingSoundSwap:OpenSettings()
    if not self.categoryID then
        self:RegisterSettings();
    end

    if self.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.categoryID);
        return true;
    end

    if self.categoryID and C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
        C_SettingsUtil.OpenSettingsPanel(self.categoryID);
        return true;
    end

    return false;
end

function PingSoundSwap:PrintStatus()
    local profile, key = self:GetActiveProfile();
    Print(string.format("Mode: %s", self:GetActiveMode()));
    Print(string.format("Profile: %s", key));
    Print(string.format("Debug: %s", self:IsDebugEnabled() and "on" or "off"));

    for _, pingType in ipairs(PING_TYPES) do
        Print(string.format("%s = %d", pingType, profile.sounds[pingType]));
    end
end

local function ParseArgs(msg)
    local args = {};
    for token in string.gmatch(msg or "", "%S+") do
        table.insert(args, token);
    end
    return args;
end

local function NormalizePingType(text)
    if not text then
        return nil;
    end

    local key = string.lower(text);
    if key == "attack" then
        return "Attack";
    elseif key == "warning" then
        return "Warning";
    elseif key == "assist" then
        return "Assist";
    elseif key == "onmyway" or key == "omw" or key == "on_my_way" then
        return "OnMyWay";
    end

    return nil;
end

function PingSoundSwap:HandleSlash(msg)
    local args = ParseArgs(msg);
    local command = string.lower(args[1] or "");

    if command == "" or command == "help" then
        Print("/pss open - Open settings");
        Print("/pss status - Show active profile and sounds");
        Print("/pss mode <character|realm|account|custom>");
        Print("/pss custom <profileKey>");
        Print("/pss set <attack|warning|assist|onmyway> <soundID>");
        Print("/pss test <attack|warning|assist|onmyway>");
        Print("/pss find <text> - Search SOUNDKIT constants");
        Print("/pss debug <on|off|status> - Toggle or show debug logging");
        return;
    end

    if command == "debug" then
        local state = string.lower(args[2] or "status");
        if state == "on" then
            self.db.debug = true;
            Print("Debug logging enabled.");
        elseif state == "off" then
            self.db.debug = false;
            Print("Debug logging disabled.");
        elseif state == "status" then
            Print(string.format("Debug logging is %s.", self:IsDebugEnabled() and "on" or "off"));
        else
            Print("Usage: /pss debug <on|off|status>");
            return;
        end

        self:Debug("Debug command processed.");
        return;
    end

    if command == "open" then
        if not self:OpenSettings() then
            Print("Settings panel is not available yet.");
        end
        return;
    end

    if command == "status" then
        self:PrintStatus();
        return;
    end

    if command == "mode" then
        local mode = string.lower(args[2] or "");
        if self:SetProfileMode(mode) then
            Print(string.format("Profile mode set to %s.", mode));
            self:PrintStatus();
        else
            Print("Invalid mode. Use character, realm, account, or custom.");
        end
        return;
    end

    if command == "custom" then
        local key = table.concat(args, " ", 2);
        if key == "" then
            Print("Usage: /pss custom <profileKey>");
            return;
        end

        self:SetCustomProfileKey(key);
        Print(string.format("Custom profile key set to %s.", NormalizeCustomKey(key)));
        if self:GetActiveMode() == "custom" then
            self:PrintStatus();
        end
        return;
    end

    if command == "set" then
        local pingType = NormalizePingType(args[2]);
        local soundID = tonumber(args[3]);

        if not pingType or not soundID then
            Print("Usage: /pss set <attack|warning|assist|onmyway> <soundID>");
            return;
        end

        if self:SetSoundForPing(pingType, soundID) then
            Print(string.format("%s set to %d.", pingType, soundID));
        else
            Print("Invalid value. SoundID must be a positive number.");
        end
        return;
    end

    if command == "test" then
        local pingType = NormalizePingType(args[2]);
        if not pingType then
            Print("Usage: /pss test <attack|warning|assist|onmyway>");
            return;
        end

        local soundID = self:GetSoundForPing(pingType);
        if self:PlaySoundMaster(soundID) then
            Print(string.format("Played %s sound (%d).", pingType, soundID));
        else
            Print("Could not play sound. Check ID and audio settings.");
        end
        return;
    end

    if command == "find" then
        local query = string.lower(table.concat(args, " ", 2));
        if query == "" then
            Print("Usage: /pss find <text>");
            return;
        end

        if type(SOUNDKIT) ~= "table" then
            Print("SOUNDKIT table is not available.");
            return;
        end

        local results = {};
        for name, id in pairs(SOUNDKIT) do
            if type(name) == "string" and type(id) == "number" and string.find(string.lower(name), query, 1, true) then
                table.insert(results, { name = name, id = id });
            end
        end

        table.sort(results, function(a, b)
            return a.name < b.name;
        end);

        if #results == 0 then
            Print("No SOUNDKIT matches found.");
            return;
        end

        local maxResults = math.min(#results, 30);
        Print(string.format("Found %d match(es). Showing %d:", #results, maxResults));
        for i = 1, maxResults do
            local item = results[i];
            Print(string.format("%s = %d", item.name, item.id));
        end
        return;
    end

    Print("Unknown command. Use /pss help.");
end

function PingSoundSwap:InitializeDatabase()
    PingSoundSwapDB = PingSoundSwapDB or {};
    PingSoundSwapCharDB = PingSoundSwapCharDB or {};

    self.db = PingSoundSwapDB;

    if type(self.db.version) ~= "number" or self.db.version < DB_VERSION then
        self.db.version = DB_VERSION;
    end

    self.db.profiles = self.db.profiles or {};
    self.db.profileMode = self.db.profileMode or "character";
    self.db.soundBuckets = self.db.soundBuckets or {};
    if type(self.db.suppressNativePingSounds) ~= "boolean" then
        self.db.suppressNativePingSounds = false;
    end
    if type(self.db.debug) ~= "boolean" then
        self.db.debug = false;
    end

    for _, pingType in ipairs(PING_TYPES) do
        if type(self.db.soundBuckets[pingType]) ~= "string" or self.db.soundBuckets[pingType] == "" then
            self.db.soundBuckets[pingType] = "curated";
        end
    end

    PingSoundSwapCharDB.customProfileKey = NormalizeCustomKey(PingSoundSwapCharDB.customProfileKey or "default");

    self:InvalidateActiveProfileCache();
    self:GetActiveProfile();
    self:ApplyNativePingSuppression();
    self:Debug("Database initialized.");
end

function PingSoundSwap:OnEvent(event, ...)
    self:Debug(string.format("Event received: %s", tostring(event)));
    if event == "PLAYER_LOGIN" then
        self:InitializeDatabase();
        self:TryHookPingManager();
        self:TryHookPingPinStyle();
        self:RegisterSettings();
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:TryHookPingManager();
        self:TryHookPingPinStyle();
    elseif event == "ADDON_LOADED" then
        local addonName = ...;
        if addonName == "Blizzard_PingUI" then
            self:TryHookPingManager();
            self:TryHookPingPinStyle();
        elseif addonName == "Blizzard_Settings_Shared" then
            self:RegisterSettings();
        end
    end
end

PingSoundSwap.frame:SetScript("OnEvent", function(_, event, ...)
    PingSoundSwap:OnEvent(event, ...);
end);

PingSoundSwap.frame:RegisterEvent("PLAYER_LOGIN");
PingSoundSwap.frame:RegisterEvent("PLAYER_ENTERING_WORLD");
PingSoundSwap.frame:RegisterEvent("ADDON_LOADED");

SLASH_PINGSOUNDSWAP1 = "/pss";
SlashCmdList.PINGSOUNDSWAP = function(msg)
    PingSoundSwap:HandleSlash(msg);
end;
