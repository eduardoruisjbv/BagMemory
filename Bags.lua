local _, BM = ...
local L=BM.L
local inventoryEvents={"BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT",
    "PLAYER_EQUIPMENT_CHANGED","PLAYERBANKSLOTS_CHANGED","PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED"}

function BM:HasOpenBags()
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _,frame in ContainerFrameUtil_EnumerateContainerFrames() do
            if frame:IsShown() then return true end
        end
    end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return true end
    for index=1,NUM_CONTAINER_FRAMES or 13 do
        local frame=_G["ContainerFrame"..index]
        if frame and frame:IsShown() then return true end
    end
    return false
end

function BM:BagVisibilityChanged()
    local open=self:HasOpenBags()
    if open==self.bagsOpen then return end
    self.bagsOpen=open
    for _,event in ipairs(inventoryEvents) do
        if open then pcall(self.events.RegisterEvent,self.events,event)
        else self.events:UnregisterEvent(event) end
    end
    self.inventoryDirty=true
    if open and self.db then
        -- Loads can finish while listeners are suspended. Re-read everything
        -- on opening, and let genuinely missing data request a fresh load.
        self.waitingItems={}
        self:ScheduleScan("BAG_OPEN")
    end
end

function BM:WatchBagFrame(frame)
    if not frame or self.bagFrames and self.bagFrames[frame] then return end
    self.bagFrames=self.bagFrames or {}
    self.bagFrames[frame]=true
    frame:HookScript("OnShow",function() self:BagVisibilityChanged() end)
    frame:HookScript("OnHide",function() self:BagVisibilityChanged() end)
end

function BM:ApplyBagIcon(button)
    if not self.config or not button then return end
    if button.IsVisible and not button:IsVisible() then return end
    local bag,slot
    if button.GetBankTabID and button.GetContainerSlotID then
        bag,slot=button:GetBankTabID(),button:GetContainerSlotID()
    elseif button.GetBagID and button.GetID then bag,slot=button:GetBagID(),button:GetID() end
    if type(bag)~="number" or type(slot)~="number" then return end
    local inBags=bag>=0 and bag<=(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)
    local inBank=false
    for _,id in ipairs(self.bankTabs or {}) do if id==bag then inBank=true; break end end
    if not inBags and not inBank then return end
    local icon=button.icon or button.Icon or button.iconTexture
    if not icon or not icon.SetDesaturated then return end
    local item=self.bySlot[bag..":"..slot]
    local info=C_Container.GetContainerItemInfo(bag,slot)
    -- Ignore a stale classification when Blizzard reuses a bag button.
    local same=item and info and item.id==info.itemID and item.link==info.hyperlink
    local junk=same and self.config.desaturate and item.action=="sell"
    icon:SetDesaturated(not not (junk or (info and info.isLocked)))
    -- Auction candidates are only highlighted; the player lists them by hand.
    local overlay=button.BagMemoryAuction
    if same and item.action=="auction" then
        if not overlay then
            overlay=button:CreateTexture(nil,"OVERLAY",nil,2)
            overlay:SetAllPoints(icon)
            overlay:SetColorTexture(1,0.82,0,0.4)
            button.BagMemoryAuction=overlay
        end
        overlay:Show()
    elseif overlay then overlay:Hide() end
end

function BM:RefreshBagIcons()
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _,frame in ContainerFrameUtil_EnumerateContainerFrames() do
            if frame:IsShown() and frame.EnumerateValidItems then
                for _,button in frame:EnumerateValidItems() do self:ApplyBagIcon(button) end
            end
        end
    end
    local panel=BankFrame and BankFrame.BankPanel
    if panel and panel:IsShown() and panel.EnumerateValidItems then
        for button in panel:EnumerateValidItems() do self:ApplyBagIcon(button) end
    end
end

local actionNames={sell=L["VENDER"],keep=L["MANTER"],review=L["REVISAR"],auction=L["LEILÃO"],bank=L["BANCO"],
    quest=L["MISSÃO"],warbank=L["BANCO DE GUERRA"]}
local actionColors={sell={1,0.35,0.35},keep={0.4,0.9,0.5},review={0.7,0.7,0.7},auction={1,0.82,0},
    bank={0.5,0.75,1},quest={1,0.82,0},warbank={0.5,0.75,1}}

-- Shows what BagMemory decided about a bag or bank item, and why.
function BM:InstallTooltip()
    if self.tooltipHook or not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType) then return end
    self.tooltipHook=true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip,data)
        pcall(function()
            if not self.items or not data or (issecretvalue and (issecretvalue(data.guid) or issecretvalue(data.hyperlink))) then return end
            for _,item in ipairs(self.items) do
                if item.storage~="equipped" and item.action
                    and ((data.guid and item.guid==data.guid) or (not data.guid and data.hyperlink and item.link==data.hyperlink)) then
                    local color=actionColors[item.action] or {1,1,1}
                    tooltip:AddLine("BagMemory: "..(actionNames[item.action] or item.action).." — "..(item.reason or "?"),
                        color[1],color[2],color[3],true)
                    if item.pvp then
                        tooltip:AddLine(string.format(L["PvP: ilvl %s → %s efetivo"],tostring(item.level),tostring(item.pvpLevel or "?")),0.7,0.7,0.7)
                    end
                    return
                end
            end
        end)
    end)
end

function BM:InstallBagHooks()
    self:InstallTooltip()
    self.bagFunctionHooks=self.bagFunctionHooks or {}
    for _,fn in ipairs({"OpenBag","CloseBag","OpenAllBags","CloseAllBags","ToggleAllBags"}) do
        if type(_G[fn])=="function" and not self.bagFunctionHooks[fn] then
            self.bagFunctionHooks[fn]=true
            hooksecurefunc(fn,function() self:BagVisibilityChanged() end)
        end
    end
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _,frame in ContainerFrameUtil_EnumerateContainerFrames() do self:WatchBagFrame(frame) end
    end
    self:WatchBagFrame(ContainerFrameCombinedBags)
    self:BagVisibilityChanged()
    if not self.iconHook and SetItemButtonDesaturated then
        self.iconHook=true
        hooksecurefunc("SetItemButtonDesaturated",function(button) self:ApplyBagIcon(button) end)
    end
    if not self.containerHook and ContainerFrameMixin and ContainerFrameMixin.UpdateItems then
        self.containerHook=true
        hooksecurefunc(ContainerFrameMixin,"UpdateItems",function(frame)
            self:WatchBagFrame(frame)
            self:BagVisibilityChanged()
            if not frame:IsShown() then return end
            if frame.EnumerateValidItems then
                for _,button in frame:EnumerateValidItems() do self:ApplyBagIcon(button) end
            end
        end)
    end
    if not self.bankIconHook and BankPanelItemButtonMixin and BankPanelItemButtonMixin.Refresh then
        self.bankIconHook=true
        hooksecurefunc(BankPanelItemButtonMixin,"Refresh",function(button) self:ApplyBagIcon(button) end)
    end
end
