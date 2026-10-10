local name, BM = ...
local L=BM.L
BM.name = name
BM.version="0.4.3"
BM.items, BM.bySlot = {}, {}
BM.waitingItems = {}
BM.defaults = {margin=10, autoSell=true, sellGear=true, lowMarket=true,
    autoRepair=true, guildRepair=false, desaturate=true, protectUpgradeable=true,
    marketProfit=5, marketAge=12, autoMarket=true, autoBank=true, pause=false, fullAuto=false, allowWarbandSale=false, setTolerance=25}
BM.consentVersion=2

function BM:IsFullAuto()
    return self.config and self.config.fullAuto==true
        and self.config.fullAutoConsent==self.consentVersion and not self.config.pause
end

function BM:StopAutomation()
    self:StopSelling()
    if self.StopBankWork then self:StopBankWork() end
    if self.StopQuestWork then self:StopQuestWork() end
end

function BM:AuthorizeFullAuto()
    self.config.fullAutoConsent=self.consentVersion
    self.config.fullAutoConsentAt=GetServerTime()
    self.config.fullAuto=true
    self.config.pause=false
    self.questAttempts={}
    self.merchantAutoBlocked=nil
    self:StopAutomation()
    self:ScheduleScan(nil,true)
    self:Print(L["Full Auto autorizado neste personagem. /bm pausa interrompe a automação."])
end

function BM:DriveAutomation()
    if self.config.pause or self.selling or self.bankWork or self.questWork then return end
    if self:CanUseBank() and (self.config.autoBank or self:IsFullAuto()) then self:StartBankWork(true)
    elseif self:CanUseMerchant() then
        if (self.config.autoSell or self:IsFullAuto()) and not self.merchantAutoBlocked
            and self:HasSaleCandidates() then self:StartSelling(true) end
    elseif self:IsFullAuto() and not self.bankOpen and not self.ahOpen then self:TryQuestItems() end
end

function BM:Print(message)
    print("|cff51d6c6BagMemory|r "..message)
end

-- A failed or restricted API read must never become permission to sell.
function BM:Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local function pack(...) return {n=select("#",...),...} end
    local result = pack(pcall(fn, ...))
    if not result[1] then return nil end
    for i=2,result.n do
        if issecretvalue and issecretvalue(result[i]) then return nil end
    end
    return unpack(result, 2, result.n)
end

function BM:Money(value)
    return GetCoinTextureString(math.max(0, math.floor(value or 0)))
end

function BM:ScheduleScan(event, service)
    if not service and not self.bagsOpen then
        self.inventoryDirty=true
        return
    end
    if InCombatLockdown() then
        self.scanAfterCombat=true
        return
    end
    if self.selling then
        -- Own sales generate bag events. The merchant validates the live bag
        -- contents itself; only other changes require rebuilding the analysis.
        self.selling.scanPending=true
        if event~="BAG_UPDATE_DELAYED" then self.selling.needsScan=true end
        return
    end
    if service then self.scanService=true end
    if not self.db or self.scanScheduled then return end
    self.scanScheduled = true
    C_Timer.After(0.25, function()
        self.scanScheduled = nil
        local serviceScan=self.scanService
        self.scanService=nil
        if not serviceScan and not self.bagsOpen then self.inventoryDirty=true; return end
        if InCombatLockdown() then self.scanAfterCombat=true; return end
        if self.selling then self.selling.scanPending=true; return end
        self.scanAfterCombat=nil
        self.inventoryDirty=nil
        self:Scan()
        self:DriveAutomation()
    end)
end

function BM:SetOption(key, value)
    self.config[key] = value
    -- A change to rules invalidates the current merchant queue immediately.
    self:StopAutomation()
    if key=="allowWarbandSale" then
        -- Refresh protections and icons synchronously; rebuild any merchant queue.
        self.merchantAutoBlocked=nil
        self.merchantFailed={}
        self:Scan()
        self:DriveAutomation()
    else self:ScheduleScan(nil,true) end
end

function BM:SetItemRule(itemID, rule)
    self.config.rules[itemID] = rule
    self:StopAutomation()
    self:ScheduleScan(nil,true)
end

function BM:Initialize()
    BagMemoryDB = type(BagMemoryDB)=="table" and BagMemoryDB or {}
    local db = BagMemoryDB
    db.characters = db.characters or {}
    local key = UnitGUID("player") or (UnitName("player").."-"..GetRealmName())
    db.characters[key] = db.characters[key] or {}
    self.db, self.config = db, db.characters[key]
    for k,v in pairs(self.defaults) do if self.config[k]==nil then self.config[k]=v end end
    self.config.rules = self.config.rules or {}
    self.config.quickProtection = self.config.quickProtection or {}
    self.config.history = self.config.history or {}
    -- Auction observations belong to this character/realm, never another realm.
    self.config.prices = self.config.prices or {}
    self.config.bankSnapshot=self.config.bankSnapshot or {}
    -- Removed equipment preferences and cached suggestions must remain inert.
    self.config.gearContext=nil
    self.config.autoEquip=nil
    for _,item in ipairs(self.config.bankSnapshot) do
        item.gearSuggested=nil; item.gearAutomatic=nil; item.gearReason=nil
    end
    self.bankValidated=false
    self.questAttempts={}
    self:InstallBagHooks()
    self:InstallQuestHooks()
    self:ScheduleScan()
    self:Call(C_MythicPlus and C_MythicPlus.RequestRewards)
    self:Print(L["Versão "]..self.version..L[" carregada. /bm abre a prévia; /bm diagnostico explica itens não vendidos."])
end

local events = CreateFrame("Frame")
BM.events = events
for _,event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEVEL_UP", "EQUIPMENT_SETS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "TRANSMOG_COLLECTION_UPDATED", "PLAYER_REGEN_ENABLED", "MERCHANT_SHOW",
    "MERCHANT_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
    "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "BANK_TABS_CHANGED", "QUEST_DETAIL", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_REMOVED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "MERCHANT_UPDATE"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_,event,...)
    if event=="ADDON_LOADED" then
        local loaded = ...
        if loaded==name then BM:Initialize()
        elseif BM.db then BM:InstallBagHooks(); BM:InstallQuestHooks() end
        return
    end
    if not BM.db then return end
    if event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        if not BM.bagsOpen then BM.inventoryDirty=true; return end
        local itemID,success=...
        if not BM.waitingItems[itemID] then return end
        BM.waitingItems[itemID]=nil
        -- Failed loads stay protected until another real inventory change.
        -- Never turn an unrelated item's load into a full inventory scan.
        if success==false then return end
        BM:ScheduleScan(event)
    elseif event=="PLAYER_REGEN_DISABLED" then BM:StopAutomation(); BM.scanAfterCombat=true
    elseif event=="PLAYER_SPECIALIZATION_CHANGED" then
        local unit=...
        if unit~="player" then return end
        BM:StopAutomation(); BM:ScheduleScan()
    elseif event=="QUEST_DETAIL" then BM:QuestDetail(...)
    elseif event=="QUEST_ACCEPTED" then BM:QuestAccepted(...)
    elseif event=="BANKFRAME_OPENED" then
        BM:BankOpened()
    elseif event=="BANKFRAME_CLOSED" then BM:BankClosed()
    elseif event=="PLAYERBANKSLOTS_CHANGED" or event=="BANK_TABS_CHANGED" then
        if not BM.bankOpen then BM.bankValidated=false end
        BM:ScheduleScan()
    elseif event=="PLAYER_ENTERING_WORLD" then
        local login,reload=...
        if login or reload then BM.bankValidated=false; BM:StopAutomation() end
        BM:ScheduleScan()
    elseif event=="MERCHANT_SHOW" then BM:MerchantOpened()
    elseif event=="MERCHANT_CLOSED" then BM.merchantOpen=nil; BM:StopSelling()
    elseif event=="MERCHANT_UPDATE" or event=="BAG_UPDATE_DELAYED" then
        if BM.selling then BM:SaleUpdated() end
        if event=="BAG_UPDATE_DELAYED" then BM:ScheduleScan(event) end
    elseif event=="AUCTION_HOUSE_SHOW" then
        -- No automatic AH queries: they trigger Blizzard's throttle/security mode.
        BM.ahOpen=true; BM:ScheduleScan(event,true)
    elseif event=="AUCTION_HOUSE_CLOSED" then BM.ahOpen=nil; BM:StopMarketScan()
    elseif event=="COMMODITY_SEARCH_RESULTS_UPDATED" or event=="ITEM_SEARCH_RESULTS_UPDATED" then
        BM:MarketResults(event,...)
    else
        BM:ScheduleScan(event)
    end
end)

SLASH_BAGMEMORY1, SLASH_BAGMEMORY2 = "/bm", "/bagmemory"
SlashCmdList.BAGMEMORY = function(message)
    if not BM.db then return end
    message = (message or ""):lower():match("^%s*(.-)%s*$")
    if message=="pausa" or message=="pause" then
        BM:SetOption("pause", not BM.config.pause)
        BM:Print(BM.config.pause and L["Automação pausada."] or L["Automação retomada."])
    elseif message=="vender" or message=="sell" then BM:StartSelling()
    elseif message=="ah" then BM:StartMarketScan()
    elseif message=="banco" or message=="bank" then BM:StartBankWork(false)
    elseif message=="full" then BM:ShowFullAutoConsent()
    elseif message=="simular" or message=="simulate" then BM:Simulate(false)
    elseif message=="simular tudo" or message=="simulate all" then BM:Simulate(true)
    elseif message=="diagnostico" or message=="diagnostics" or message=="status" then BM:PrintDiagnostics()
    else BM:ToggleUI() end
end
