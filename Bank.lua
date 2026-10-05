local _, BM = ...
local L=BM.L

-- Ring buffer of bank decisions, saved with the addon data for diagnosis.
function BM:BankLog(...)
    if not self.db then return end
    local parts={}
    for i=1,select("#",...) do parts[i]=tostring((select(i,...))) end
    local log=self.db.bankLog or {}
    self.db.bankLog=log
    log[#log+1]=string.format("%.1f ",GetTime())..table.concat(parts," ")
    while #log>80 do table.remove(log,1) end
end

function BM:CanReadBank(bankType)
    bankType=bankType or (Enum.BankType and Enum.BankType.Character)
    return self.bankOpen and BankFrame and BankFrame:IsShown() and C_Bank and bankType
        and self:Call(C_Bank.CanUseBank,bankType)==true
end

-- The bank tab the player is looking at: transfers always go to or from it.
function BM:ActiveBankType()
    if not (BankFrame and BankFrame.GetActiveBankType) then return nil end
    return self:Call(BankFrame.GetActiveBankType,BankFrame)
end

function BM:CanUseBank()
    local active=self:ActiveBankType()
    return active~=nil and self:CanReadBank(active)
        and not InCombatLockdown() and not GetCursorInfo()
        and not (SpellCanTargetItem and SpellCanTargetItem())
end

-- Live read of the warband bank. It is never persisted: unseen warband items
-- are simply not part of the analysis until the bank is opened again.
function BM:ReadWarbandItems()
    local bankType=Enum.BankType and Enum.BankType.Account
    local items={}
    if not bankType or not self:CanReadBank(bankType) then return items end
    local tabs=self:Call(C_Bank.FetchPurchasedBankTabIDs,bankType)
    if type(tabs)~="table" then return items end
    for _,bag in ipairs(tabs) do
        for slot=1,(self:Call(C_Container.GetContainerNumSlots,bag) or 0) do
            local container=self:Call(C_Container.GetContainerItemInfo,bag,slot)
            if container then
                local item=self:ReadItem(container.hyperlink or container.itemID,
                    ItemLocation:CreateFromBagAndSlot(bag,slot),bag,slot,nil,container)
                item.storage="bank"; item.liveBank=true; item.bankType=bankType
                items[#items+1]=item
            end
        end
    end
    return items
end

local function copySnapshot(item)
    local copy={}
    for key,value in pairs(item) do
        local kind=type(value)
        if (kind=="string" or kind=="number" or kind=="boolean")
            and key~="liveBank" and key~="locked" then copy[key]=value end
    end
    copy.storage="bank"
    return copy
end

function BM:ReadBankItems()
    local snapshot=self.config.bankSnapshot or {}
    if self:CanReadBank() then
        local tabs=self:Call(C_Bank.FetchPurchasedBankTabIDs,Enum.BankType.Character)
        local purchased=self:Call(C_Bank.FetchNumPurchasedBankTabs,Enum.BankType.Character)
        if type(tabs)=="table" and type(purchased)=="number" and #tabs==purchased then
            local items,complete={},true
            self.bankTabs=tabs
            for _,bag in ipairs(tabs) do
                local slots=self:Call(C_Container.GetContainerNumSlots,bag)
                if not slots or slots==0 then complete=false end
                for slot=1,(slots or 0) do
                    local container=self:Call(C_Container.GetContainerItemInfo,bag,slot)
                    if container then
                        local item=self:ReadItem(container.hyperlink or container.itemID,
                            ItemLocation:CreateFromBagAndSlot(bag,slot),bag,slot,nil,container)
                        item.storage="bank"; item.liveBank=true
                        items[#items+1]=item
                        if item.pending or item.questUnknown or item.tooltipUnknown then complete=false end
                    elseif self:Call(C_Container.GetContainerItemID,bag,slot) then complete=false end
                end
            end
            if complete then
                local saved={}
                for _,item in ipairs(items) do saved[#saved+1]=copySnapshot(item) end
                self.config.bankSnapshot=saved
                self.config.bankSnapshotAt=GetServerTime()
                self.bankValidated=true
                return items
            end
            self.bankValidated=false
            -- Keep both the visible data and old unmatched records as protection
            -- until the bank finishes loading. Never drop unseen equipment early.
            local seen={}
            for _,item in ipairs(items) do seen[item.guid or item.link]=true end
            for _,item in ipairs(snapshot) do
                if not seen[item.guid or item.link] then items[#items+1]=copySnapshot(item) end
            end
            return items
        end
        self.bankValidated=false
    end
    local items={}
    for _,saved in ipairs(snapshot) do
        local item=copySnapshot(saved)
        if item.questID then
            item.questOnLog=self:Call(C_QuestLog.IsOnQuest,item.questID)
            item.questActive=item.questOnLog==true
            item.questCompleted=self:Call(C_QuestLog.IsQuestFlaggedCompleted,item.questID)
        end
        if self.questNeededItems[item.id] then item.quest=true; item.questActive=true end
        items[#items+1]=item
    end
    return items
end

function BM:BankClosed()
    -- Refresh the last live snapshot before dropping access when the API permits it.
    self:StopBankWork()
    self.bankOpen=nil
    self:ScheduleScan()
end

function BM:StopBankWork()
    self.bankGeneration=(self.bankGeneration or 0)+1
    self.bankWork=nil
end

function BM:BankTransferDirection(item)
    local active=self:ActiveBankType()
    local character=Enum.BankType and Enum.BankType.Character
    -- Marked items are deposited only into the character bank, never by accident
    -- into the warband bank because that tab happens to be open.
    if item.storage=="bag" and item.action=="bank" and active==character then return "deposit" end
    if item.storage=="bank" and item.liveBank and (item.bankType or character)==active then
        if item.action=="sell" then return "withdraw" end
        if self:IsFullAuto() and (item.questActive or item.action=="quest") then return "withdraw" end
    end
end

-- Fresh read every time a bank opens or its tab changes. Data loads late, so the
-- read repeats until the bank validates (bounded) and reacts to tab switches.
function BM:BankOpened()
    self.bankOpen=true
    self.bankBlocked={}
    self.bankRetries=0
    self.bankLastType=nil
    self:StopQuestWork()
    self:BankLog("aberto","active",self:ActiveBankType(),"frameShown",BankFrame and BankFrame:IsShown())
    self:ScheduleScan("BANKFRAME_OPENED",true)
    self:BankWatch()
end

function BM:BankWatch()
    if self.bankWatching then return end
    self.bankWatching=true
    local function tick()
        if not self.bankOpen then self.bankWatching=nil; return end
        local active=self:ActiveBankType()
        local changed=active~=self.bankLastType
        if changed or (not self.bankValidated and (self.bankRetries or 0)<8) then
            if not changed then self.bankRetries=(self.bankRetries or 0)+1 end
            self.bankLastType=active
            if changed then self:BankLog("aba ativa",active) end
            self.bankBlocked={}
            self:ScheduleScan("BANK_REFRESH",true)
        end
        C_Timer.After(1,tick)
    end
    C_Timer.After(0.5,tick)
end

function BM:StartBankWork(automatic)
    if self.bankWork then return end
    if not automatic then self.bankBlocked={} end
    if self.config.pause or (automatic and not (self:IsFullAuto() or self.config.autoBank)) then
        self:BankLog("start: bloqueado por pausa/config","pause",self.config.pause,"auto",automatic,"fullAuto",self:IsFullAuto(),"autoBank",self.config.autoBank)
        return
    end
    if not self:CanUseBank() then
        self:BankLog("start: CanUseBank=false","bankOpen",self.bankOpen,"frameShown",BankFrame and BankFrame:IsShown(),
            "active",self:ActiveBankType(),"combat",InCombatLockdown(),"cursor",GetCursorInfo()~=nil)
        if not automatic then self:Print(L["Abra o banco do personagem, fora de combate e com o cursor vazio."]) end
        return
    end
    self:Scan()
    if not self.bankValidated then
        self:BankLog("start: banco nao validado","active",self:ActiveBankType())
        if not automatic then self:Print(L["Aguarde o carregamento completo do banco."]) end
        return
    end
    local queue={}
    -- Deposits first release space for withdrawals. Classification is rechecked
    -- before every transfer, so mission or equipment changes cancel that move.
    for _,direction in ipairs({"deposit","withdraw"}) do
        for _,item in ipairs(self.items) do
            if self:BankTransferDirection(item)==direction then
                local key=(item.guid or item.link)..":"..direction
                if not self.bankBlocked or not self.bankBlocked[key] then
                    queue[#queue+1]={bag=item.bag,slot=item.slot,guid=item.guid,link=item.link,
                        count=item.count,id=item.id,direction=direction,key=key}
                end
            end
        end
    end
    do
        local dep,ret=0,0
        for _,q in ipairs(queue) do if q.direction=="deposit" then dep=dep+1 else ret=ret+1 end end
        self:BankLog("fila","active",self:ActiveBankType(),"depositar",dep,"retirar",ret)
    end
    if #queue==0 then return end
    self.bankGeneration=(self.bankGeneration or 0)+1
    local state={queue=queue,index=0,moved=0,generation=self.bankGeneration,automatic=automatic}
    self.bankWork=state
    self:NextBankTransfer(state)
end

function BM:FinishBankWork(state,reason)
    if self.bankWork~=state then return end
    self.bankWork=nil
    self:BankLog("fim","movidas",state.moved,"motivo",reason or "-")
    if state.moved>0 then self:Print(string.format(L["Banco: %d pilhas transferidas."],state.moved)) end
    if reason then self:Print(reason) end
    self:ScheduleScan()
end

function BM:NextBankTransfer(state)
    if self.bankWork~=state or state.generation~=self.bankGeneration then return end
    if not self:CanUseBank() or self.config.pause
        or (state.automatic and not (self:IsFullAuto() or self.config.autoBank)) then
        self:FinishBankWork(state); return
    end
    state.index=state.index+1
    local snapshot=state.queue[state.index]
    if not snapshot then self:FinishBankWork(state); return end
    self:Scan()
    local item=self.bySlot[snapshot.bag..":"..snapshot.slot]
    if not item or not self.bankValidated or item.locked or item.link~=snapshot.link
        or item.count~=snapshot.count or (snapshot.guid and item.guid~=snapshot.guid)
        or self:BankTransferDirection(item)~=snapshot.direction then
        self:BankLog("pulou","item",snapshot.link,"dir",snapshot.direction,"existe",item~=nil,
            "validado",self.bankValidated,"locked",item and item.locked,
            "mesmoLink",item and item.link==snapshot.link,"dirAgora",item and self:BankTransferDirection(item))
        C_Timer.After(0.15,function() self:NextBankTransfer(state) end); return
    end
    local transferType=(snapshot.direction=="withdraw" and item.bankType) or Enum.BankType.Character
    local allowed=self:Call(C_Bank.IsItemAllowedInBankType,transferType,item.location)
    if snapshot.direction=="deposit" and allowed~=true then
        self.bankBlocked=self.bankBlocked or {}; self.bankBlocked[snapshot.key]=true
        C_Timer.After(0.15,function() self:NextBankTransfer(state) end); return
    end
    if snapshot.direction=="withdraw" then
        local free=0
        -- A free ordinary bag slot is required. A reagent bag is insufficient
        -- for equipment and mission starters; keep those in the bank if full.
        for bag=0,(NUM_BAG_SLOTS or 4) do
            local count,family=self:Call(C_Container.GetContainerNumFreeSlots,bag)
            if family==0 then free=free+(count or 0) end
        end
        if free==0 then
            self.bankBlocked=self.bankBlocked or {}; self.bankBlocked[snapshot.key]=true
            self:FinishBankWork(state,L["Mochila sem espaço compatível para retirar os itens."]); return
        end
    end
    self:BankLog("mover",snapshot.direction,snapshot.link,"tipo",transferType,"bag",item.bag,"slot",item.slot)
    local before=self:Call(C_Item.GetItemCount,item.id,false,false,false,false)
    if before==nil then self:FinishBankWork(state,L["Contagem do item não confirmada; transferência interrompida."]); return end
    local ok,err=pcall(C_Container.UseContainerItem,item.bag,item.slot,nil,transferType,false)
    if not ok then
        self:BankLog("UseContainerItem falhou",err)
        self.bankBlocked=self.bankBlocked or {}; self.bankBlocked[snapshot.key]=true
        self:FinishBankWork(state,L["O jogo bloqueou a transferência. O item continua preservado."]); return
    end
    local started=GetTime()
    local function acknowledge()
        if self.bankWork~=state or state.generation~=self.bankGeneration then return end
        if not self:CanUseBank() then self:FinishBankWork(state); return end
        local count=self:Call(C_Item.GetItemCount,item.id,false,false,false,false)
        local expected=before+(snapshot.direction=="withdraw" and item.count or -item.count)
        if count==expected then
            state.moved=state.moved+1
            C_Timer.After(0.2,function() self:NextBankTransfer(state) end)
        elseif GetTime()-started<2 then C_Timer.After(0.15,acknowledge)
        else
            self.bankBlocked=self.bankBlocked or {}; self.bankBlocked[snapshot.key]=true
            self:FinishBankWork(state,L["Transferência não confirmada. Confira o espaço e as regras do banco."])
        end
    end
    C_Timer.After(0.2,acknowledge)
end
