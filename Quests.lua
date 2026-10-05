local _, BM = ...
local L=BM.L

function BM:StartQuestManually(item)
    if item.storage~="bag" or self.bankOpen or self.merchantOpen or self.ahOpen
        or InCombatLockdown() or GetCursorInfo() then
        self:Print(L["Use o item da mochila fora de combate, com banco, vendedor e AH fechados."]); return
    end
    self:Scan()
    local live=self.bySlot[item.bag..":"..item.slot]
    if not live or not live.questStarter or live.link~=item.link or live.locked
        or (item.guid and live.guid~=item.guid) then return end
    if self:IsFullAuto() then
        self.questAttempts[live.guid or live.link]=nil
        self:TryQuestItems(live)
    else pcall(C_Container.UseContainerItem,live.bag,live.slot) end
end

function BM:ReadQuestNeeds()
    self.questNeededItems={}
    local entries=self:Call(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or 0
    for index=1,entries do
        local info=self:Call(C_QuestLog.GetInfo,index)
        if info and not info.isHeader then
            local link=self:Call(GetQuestLogSpecialItemInfo,index)
            local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
            if id then self.questNeededItems[id]=true end
        end
    end
end

function BM:HasQuestLogSpace()
    local max=self:Call(C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept)
    local entries=self:Call(C_QuestLog and C_QuestLog.GetNumQuestLogEntries)
    if not max or not entries then return false end
    local count=0
    for index=1,entries do
        local info=self:Call(C_QuestLog.GetInfo,index)
        if not info then return false end
        if not info.isHeader and not info.isHidden and not info.isTask then count=count+1 end
    end
    return count<max
end

function BM:StopQuestWork()
    self.questGeneration=(self.questGeneration or 0)+1
    self.questWork=nil
end

function BM:TryQuestItems(selected)
    if not self:IsFullAuto() or self.questWork or self.bankWork or self.selling
        or InCombatLockdown() or GetCursorInfo() or self.bankOpen or self.merchantOpen or self.ahOpen
        or (QuestFrame and QuestFrame:IsShown()) or not self:HasQuestLogSpace() then return end
    self.questAttempts=self.questAttempts or {}
    for _,item in ipairs(selected and {selected} or self.items) do
        local key=item.guid or item.link
        if item.storage=="bag" and item.questStarter and item.action=="quest" and not item.locked
            and not item.questUnknown and not item.tooltipUnknown and not self.questAttempts[key] then
            local live=self:Call(C_Container.GetContainerItemInfo,item.bag,item.slot)
            if live and live.hyperlink==item.link and not live.isLocked
                and (not item.guid or self:Call(C_Item.GetItemGUID,item.location)==item.guid) then
                self.questAttempts[key]=true
                self.questGeneration=(self.questGeneration or 0)+1
                local state={itemID=item.id,questID=item.questID,generation=self.questGeneration,
                    key=key,started=GetTime()}
                self.questWork=state
                local ok=pcall(C_Container.UseContainerItem,item.bag,item.slot)
                if not ok then self.questWork=nil; self:Print(L["O jogo bloqueou o início da missão; item preservado."]); return end
                C_Timer.After(8,function()
                    if self.questWork==state then
                        self.questWork=nil
                        self:Print(L["Missão do item não confirmada. Use o item manualmente; ele permanece protegido."])
                        self:RefreshUI()
                    end
                end)
                self:RefreshUI()
                return
            end
        end
    end
end

function BM:QuestOfferFromItem(questID,itemID)
    local state=self.questWork
    if not self:IsFullAuto() or not state or state.itemID~=itemID or state.reopening
        or state.generation~=self.questGeneration then return end
    if state.questID and state.questID~=questID then return end
    state.questID=questID; state.reopening=true
    -- Blizzard turns item offers into tracker popups and closes the first dialog.
    -- Reopen that exact offer after its handler finishes, then accept QUEST_DETAIL.
    C_Timer.After(0.15,function()
        if self.questWork~=state or not self:IsFullAuto() or InCombatLockdown()
            or self.bankOpen or self.merchantOpen or not self:HasQuestLogSpace() then return end
        if ShowQuestOffer then pcall(ShowQuestOffer,questID) end
    end)
end

function BM:QuestDetail(startItemID)
    local state=self.questWork
    if not self:IsFullAuto() or not state or state.generation~=self.questGeneration
        or InCombatLockdown() or self.bankOpen or self.merchantOpen then return end
    local questID=self:Call(GetQuestID)
    if not questID or questID<=0 then return end
    if startItemID and startItemID>0 then
        if startItemID~=state.itemID then return end
        self:QuestOfferFromItem(questID,startItemID)
        return
    end
    if state.questID~=questID or state.accepting or not self:HasQuestLogSpace() then return end
    state.accepting=true
    local ok
    if QuestGetAutoAccept and self:Call(QuestGetAutoAccept) then ok=pcall(AcknowledgeAutoAcceptQuest)
    else ok=pcall(AcceptQuest) end
    if not ok then self.questWork=nil; self:Print(L["Aceitação bloqueada pelo jogo; missão preservada para aceitar manualmente."]) end
end

function BM:QuestAccepted(first,second)
    local state=self.questWork
    local questID=second or first
    if state and state.questID==questID then
        self.questWork=nil
        self:Print(L["Missão do item aceita: "]..questID..".")
    end
    self:ScheduleScan()
end

function BM:InstallQuestHooks()
    if not self.questOfferHook and QuestObjectiveTracker and QuestObjectiveTracker.AddAutoQuestPopUp then
        self.questOfferHook=true
        hooksecurefunc(QuestObjectiveTracker,"AddAutoQuestPopUp",function(_,questID,popUpType,itemID)
            if popUpType=="OFFER" and itemID then self:QuestOfferFromItem(questID,itemID) end
        end)
    end
end
