local _, BM = ...
local L = BM.L
local HOLD_SECONDS = 4

-- Session-only: never put these IDs in SavedVariables or the bank snapshot.
BM.temporaryBankProtection = {}

local function public(value)
    return not (issecretvalue and issecretvalue(value))
end

function BM:IsItemProtected(item)
    local id = type(item)=="table" and item.id or item
    if not public(id) or type(id)~="number" or not self.config then return false end
    return self.config.quickProtection and self.config.quickProtection[id]==true
        or self.config.rules and self.config.rules[id]=="keep" or false
end

function BM:IsBankReturnProtected(item)
    local id = type(item)=="table" and item.id or item
    return public(id) and type(id)=="number" and self.temporaryBankProtection[id]==true
end

function BM:IsProtectionBankBag(bag)
    if not public(bag) or type(bag)~="number" then return false end
    local index = Enum and Enum.BagIndex
    if index then
        if index.CharacterBankTab_1 and index.CharacterBankTab_6
            and bag>=index.CharacterBankTab_1 and bag<=index.CharacterBankTab_6 then return true end
        if index.AccountBankTab_1 and index.AccountBankTab_5
            and bag>=index.AccountBankTab_1 and bag<=index.AccountBankTab_5 then return true end
    end
    for _,id in ipairs(self.bankTabs or {}) do if bag==id then return true end end
    return false
end

function BM:ProtectionButtonSlot(button)
    if not button then return end
    local bag, slot
    if button.GetBankTabID and button.GetContainerSlotID then
        bag, slot = self:Call(button.GetBankTabID,button), self:Call(button.GetContainerSlotID,button)
    elseif button.GetBagID and button.GetID then
        bag, slot = self:Call(button.GetBagID,button), self:Call(button.GetID,button)
    end
    if type(bag)~="number" or type(slot)~="number" or slot<1 then return end
    if not (bag>=0 and bag<=(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5))
        and not self:IsProtectionBankBag(bag) then return end
    return bag, slot
end

function BM:ProtectionButtonItem(button)
    local bag, slot = self:ProtectionButtonSlot(button)
    if not bag then return end
    local info = self:Call(C_Container.GetContainerItemInfo,bag,slot)
    if not info or not public(info.itemID) or not public(info.hyperlink)
        or not public(info.isLocked) or type(info.itemID)~="number" or info.isLocked then return end
    local guid = self:Call(C_Item.GetItemGUID,ItemLocation:CreateFromBagAndSlot(bag,slot))
    return {id=info.itemID,link=info.hyperlink,guid=guid,bag=bag,slot=slot}
end

function BM:ProtectionChanged()
    -- Invalidate queued transfers, vendor bursts and pending item quest offers
    -- immediately; their next scan must see the new protection.
    self:StopAutomation()
    self:RefreshBagIcons()
    self:ScheduleScan("ITEM_PROTECTION",true)
end

function BM:ToggleQuickProtection(id)
    if not self.config or not public(id) or type(id)~="number" then return end
    self.config.quickProtection = self.config.quickProtection or {}
    local protected = self:IsItemProtected(id)
    if protected then
        self.config.quickProtection[id] = nil
        -- The existing Protect item button uses this rule; the same gesture
        -- can unlock it, too. Other bank/sell rules stay intact underneath.
        if self.config.rules[id]=="keep" then self.config.rules[id]=nil end
        self.temporaryBankProtection[id] = nil
    else
        self.config.quickProtection[id] = true
    end
    self:Print(string.format(protected and L["Proteção removida: item %d."]
        or L["Item %d protegido contra ações do BagMemory. Ctrl por 4 s remove a proteção."],id))
    self:ProtectionChanged()
end

function BM:ProtectBankReturn(id)
    if not self.config or not public(id) or type(id)~="number"
        or self.temporaryBankProtection[id] then return end
    self.temporaryBankProtection[id] = true
    self:Print(string.format(L["Item %d: não devolver ao banco até o próximo login ou /reload."],id))
    self:ProtectionChanged()
end

function BM:ProtectionPickup(bag,slot)
    if not self.config or not public(bag) or type(bag)~="number" then return end
    local kind, id = self:Call(GetCursorInfo)
    if self:IsProtectionBankBag(bag) and kind=="item" and type(id)=="number" then
        self.protectionPickup = {id=id}
        if IsControlKeyDown() then self:ProtectBankReturn(id) end
    elseif bag>=0 and bag<=(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) then
        local pickup = self.protectionPickup
        -- Ctrl may be pressed after starting the drag, or just before dropping.
        if pickup and IsControlKeyDown() then self:ProtectBankReturn(pickup.id) end
        self.protectionPickup = nil
    end
end

function BM:ApplyProtectionIcon(button,id,icon)
    local protected = self:IsItemProtected(id)
    local temporary = self:IsBankReturnProtected(id)
    local marker = button.BagMemoryProtection
    if protected or temporary then
        if not marker then
            marker = button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            button.BagMemoryProtection = marker
        end
        marker:ClearAllPoints()
        marker:SetPoint("TOPLEFT",icon,"TOPLEFT",1,-1)
        marker:SetText("|cffffd34eP|r")
        marker:Show()
    elseif marker then marker:Hide() end
    local temporaryMarker = button.BagMemoryTemporaryProtection
    if temporary then
        if not temporaryMarker then
            temporaryMarker = button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            button.BagMemoryTemporaryProtection = temporaryMarker
        end
        temporaryMarker:ClearAllPoints()
        temporaryMarker:SetPoint("TOPRIGHT",icon,"TOPRIGHT",-1,-1)
        temporaryMarker:SetText("|cff65bfffT|r")
        temporaryMarker:Show()
    elseif temporaryMarker then temporaryMarker:Hide() end
end

function BM:CancelProtectionHold()
    local hold = self.protectionHold
    if hold and hold.button.BagMemoryProtectionTimer then hold.button.BagMemoryProtectionTimer:Hide() end
    self.protectionHold = nil
    if self.protectionFrame then self.protectionFrame:SetScript("OnUpdate",nil) end
end

function BM:BeginProtectionHover(button)
    self:CancelProtectionHold()
    local item = self.config and self:ProtectionButtonItem(button)
    if not item then return end
    self.protectionHold = {button=button,elapsed=0}
    self.protectionFrame:SetScript("OnUpdate",function(_,elapsed) self:UpdateProtectionHold(elapsed) end)
    if IsControlKeyDown() and self:Call(GetCursorInfo)==nil and not self:IsItemProtected(item) then
        self:ProtectBankReturn(item.id)
    end
end

function BM:UpdateProtectionHold(elapsed)
    local hold = self.protectionHold
    if not hold then return end
    local button = hold.button
    if not button:IsShown() or not button:IsMouseOver() then self:CancelProtectionHold(); return end
    hold.elapsed = hold.elapsed+elapsed
    if hold.elapsed<0.05 then return end
    hold.elapsed = 0
    if not IsControlKeyDown() or self:Call(GetCursorInfo)~=nil then
        hold.started, hold.item, hold.toggled, hold.clicked = nil, nil, nil, nil
        if button.BagMemoryProtectionTimer then button.BagMemoryProtectionTimer:Hide() end
        return
    end
    if hold.clicked then return end
    local item = self:ProtectionButtonItem(button)
    if not item then
        hold.started, hold.item, hold.toggled = nil, nil, nil
        if button.BagMemoryProtectionTimer then button.BagMemoryProtectionTimer:Hide() end
        return
    end
    local previous = hold.item
    if not previous or item.id~=previous.id or item.guid~=previous.guid or item.link~=previous.link
        or item.bag~=previous.bag or item.slot~=previous.slot then
        hold.item, hold.started, hold.toggled = item, GetTime(), nil
    end
    if hold.toggled then return end
    local remaining = HOLD_SECONDS-(GetTime()-hold.started)
    if remaining<=0 then
        hold.toggled = true -- exactly one toggle until Ctrl is released or the pointer leaves
        if button.BagMemoryProtectionTimer then button.BagMemoryProtectionTimer:Hide() end
        self:ToggleQuickProtection(item.id)
        return
    end
    if not button.BagMemoryProtectionTimer then
        local timer = button:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        timer:SetPoint("CENTER",button,"CENTER",0,0)
        timer:SetTextColor(1,0.85,0.3)
        button.BagMemoryProtectionTimer = timer
    end
    button.BagMemoryProtectionTimer:SetText(tostring(math.ceil(remaining)))
    button.BagMemoryProtectionTimer:Show()
end

function BM:WatchProtectionButton(button)
    if not button or button.BagMemoryProtectionHook then return end
    button.BagMemoryProtectionHook = true
    button:HookScript("OnEnter",function() self:BeginProtectionHover(button) end)
    button:HookScript("OnMouseDown",function()
        local hold = self.protectionHold
        if hold and hold.button==button then
            hold.started, hold.item, hold.toggled, hold.clicked = nil, nil, nil, true
            if button.BagMemoryProtectionTimer then button.BagMemoryProtectionTimer:Hide() end
        end
    end)
    local function leave()
        if self.protectionHold and self.protectionHold.button==button then self:CancelProtectionHold() end
    end
    button:HookScript("OnLeave",leave)
    button:HookScript("OnHide",leave)
    -- Hooks can be installed during a refresh with the pointer already over it.
    if button:IsShown() and button:IsMouseOver() then self:BeginProtectionHover(button) end
end

function BM:ProtectionTooltip(tooltip,item)
    if self:IsItemProtected(item) then
        tooltip:AddLine(L["P: proteção persistente contra ações do BagMemory."],1,0.83,0.3,true)
    elseif self:IsBankReturnProtected(item) then
        tooltip:AddLine(L["T: não devolver ao banco até login ou /reload."],0.4,0.75,1,true)
    end
    tooltip:AddLine(L["Ctrl: proteção temporária de banco. Ctrl por 4 s: proteger/desproteger este tipo de item."],0.7,0.8,0.8,true)
end

function BM:InstallProtectionHooks()
    if self.protectionFrame then return end
    local frame = CreateFrame("Frame")
    self.protectionFrame = frame
    frame:RegisterEvent("MODIFIER_STATE_CHANGED")
    frame:RegisterEvent("CURSOR_CHANGED")
    frame:SetScript("OnEvent",function(_,event,key)
        if event=="CURSOR_CHANGED" then
            local kind = self:Call(GetCursorInfo)
            if kind~="item" then self.protectionPickup=nil end
            local hold = self.protectionHold
            if kind~=nil and hold then
                hold.started, hold.item, hold.toggled = nil, nil, nil
                if hold.button.BagMemoryProtectionTimer then hold.button.BagMemoryProtectionTimer:Hide() end
            end
            return
        end
        if key~="LCTRL" and key~="RCTRL" then return end
        local pickup = self.protectionPickup
        local kind, id = self:Call(GetCursorInfo)
        if pickup and kind=="item" and id==pickup.id and IsControlKeyDown() then
            self:ProtectBankReturn(pickup.id)
        end
        -- Reset on key-up immediately, even if it happens between update ticks.
        local hold = self.protectionHold
        if hold and IsControlKeyDown() and kind==nil then
            local item = self:ProtectionButtonItem(hold.button)
            if item and not self:IsItemProtected(item) then self:ProtectBankReturn(item.id) end
        end
        if hold and not IsControlKeyDown() then
            hold.started, hold.item, hold.toggled, hold.clicked = nil, nil, nil, nil
            if hold.button.BagMemoryProtectionTimer then hold.button.BagMemoryProtectionTimer:Hide() end
        end
    end)
    hooksecurefunc(C_Container,"PickupContainerItem",function(bag,slot) self:ProtectionPickup(bag,slot) end)
    if ClearCursor then hooksecurefunc("ClearCursor",function() self.protectionPickup=nil end) end
end
