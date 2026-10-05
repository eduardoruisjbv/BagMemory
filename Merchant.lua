local _, BM = ...
local L=BM.L

function BM:CanUseMerchant()
    return self.merchantOpen and MerchantFrame and MerchantFrame:IsShown()
        and not InCombatLockdown() and not GetCursorInfo()
        and not (SpellCanTargetItem and SpellCanTargetItem())
end

function BM:Repair()
    if self.config.pause or not (self.config.autoRepair or self:IsFullAuto())
        or not self:CanUseMerchant() or not CanMerchantRepair() then return end
    local cost,needed=GetRepairAllCost()
    if not needed or not cost or cost<=0 then return end
    if self.config.guildRepair and CanGuildBankRepair() then
        local limit=GetGuildBankWithdrawMoney()
        if (limit==-1 or limit>=cost) and GetGuildBankMoney()>=cost then
            RepairAllItems(true)
            self:Print(L["Reparo solicitado à guilda: "]..self:Money(cost)..".")
            return
        end
    end
    if GetMoney()>=cost then
        RepairAllItems(false)
        self:Print(L["Reparo solicitado: "]..self:Money(cost)..".")
    else self:Print(L["Faltam moedas para reparar: "]..self:Money(cost)..".") end
end

function BM:MerchantOpened()
    self.merchantOpen=true
    self.merchantAutoBlocked=nil
    self.merchantFailed={}
    self.saleReport=nil
    self:StopQuestWork()
    self:Scan()
    self:Repair()
    if (self.config.autoSell or self:IsFullAuto()) and not self.config.pause then
        C_Timer.After(0.1,function()
            if (self.config.autoSell or self:IsFullAuto()) and not self.config.pause then self:StartSelling(true) end
        end)
    end
end

function BM:StopSelling()
    local state=self.selling
    if state then
        self.saleReport=string.format(L["Venda interrompida: %d / %d pilhas confirmadas."],state.sold,state.total or #state.queue)
    end
    self.saleGeneration=(self.saleGeneration or 0)+1
    self.selling=nil
    self:RefreshUI()
end

-- Lightweight inventory checkpoint. A removed inferior item cannot alter the
-- protected best items. Any other change invalidates this checkpoint and forces
-- the full comparison before the next transaction.
function BM:CaptureSaleInventory()
    local slots={}
    for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
        for slot=1,(self:Call(C_Container.GetContainerNumSlots,bag) or 0) do
            local info=self:Call(C_Container.GetContainerItemInfo,bag,slot)
            if info then
                local loc=ItemLocation:CreateFromBagAndSlot(bag,slot)
                slots[bag..":"..slot]={id=info.itemID,link=info.hyperlink,count=info.stackCount,
                    bound=info.isBound,guid=self:Call(C_Item.GetItemGUID,loc),bag=bag,slot=slot}
            elseif self:Call(C_Container.GetContainerItemID,bag,slot) then return nil end
        end
    end
    return slots
end

local function identical(a,b)
    return a and b and a.id==b.id and a.link==b.link and a.count==b.count and a.guid==b.guid and a.bound==b.bound
end

local function inventoryMatches(a,b)
    if not a or not b then return false end
    for slot,item in pairs(a) do if not identical(item,b[slot]) then return false end end
    for slot in pairs(b) do if not a[slot] then return false end end
    return true
end

function BM:SaleKey(item)
    return item.guid or (tostring(item.bag)..":"..tostring(item.slot)..":"..tostring(item.link))
end

function BM:HasSaleCandidates()
    for _,item in ipairs(self.items) do
        if item.storage=="bag" and item.action=="sell" and not (self.merchantFailed or {})[self:SaleKey(item)] then return true end
    end
    return false
end

function BM:SaleRemainder()
    local counts={sell=0,keep=0,review=0,bank=0,auction=0,quest=0,warbank=0}
    for _,item in ipairs(self.items) do if item.storage=="bag" then counts[item.action]=(counts[item.action] or 0)+1 end end
    return string.format(L["Mochila: %d venda · %d manter · %d revisar · %d banco · %d guerra · %d AH · %d missões"],
        counts.sell,counts.keep,counts.review,counts.bank,counts.warbank,counts.auction,counts.quest)
end

function BM:PrintDiagnostics()
    self:Scan()
    self:Print(string.format(L["Versão %s · %s · Banco %s · Margem %d · Aprimoráveis %s"],self.version,
        self:IsFullAuto() and L["Full Auto autorizado"] or "Semi Auto",self.bankValidated and "confirmado" or L["precisa abrir"],
        self.config.margin,self.config.protectUpgradeable and "protegidos" or L["usando ilvl atual"]))
    self:Print(self:SaleRemainder())
    if self.saleReport then self:Print(self.saleReport) end
    local reasons={}
    for _,item in ipairs(self.items) do
        if item.storage=="bag" and item.action~="sell" then reasons[item.reason]=(reasons[item.reason] or 0)+1 end
    end
    local grouped={};for reason,count in pairs(reasons) do grouped[#grouped+1]={reason=reason,count=count} end
    table.sort(grouped,function(a,b) return a.count>b.count or a.count==b.count and a.reason<b.reason end)
    for i=1,math.min(8,#grouped) do self:Print(grouped[i].count..L[" pilhas: "]..grouped[i].reason) end
end

function BM:RecordConfirmedSale(state,item,quiet)
    state.sold=state.sold+1
    local value=item.sellPrice*item.count
    state.value=state.value+value
    state.inventory[item.bag..":"..item.slot]=nil
    local history=self.config.history
    history[#history+1]={link=item.link,id=item.id,count=item.count,value=value,time=GetServerTime(),reason=item.reason}
    if #history>60 then table.remove(history,1) end
    for i=#self.items,1,-1 do
        local cached=self.items[i]
        if cached.storage=="bag" and self:SaleKey(cached)==self:SaleKey(item) then
            table.remove(self.items,i);break
        end
    end
    self.bySlot[item.bag..":"..item.slot]=nil
    self.summary.sell=math.max(0,(self.summary.sell or 0)-1)
    self.summary.bagSell=math.max(0,(self.summary.bagSell or 0)-1)
    self.summary.value=math.max(0,(self.summary.value or 0)-value)
    if not quiet then self:RefreshUI() end
end

function BM:StartSelling(automatic)
    if self.selling or self.bankWork or self.questWork then return end
    if automatic and self.merchantAutoBlocked then return end
    if self.config.pause then self:Print(L["Vendas pausadas. Retome em /bm."]); return end
    if not self:CanUseMerchant() then self:Print(L["Abra um vendedor fora de combate, com o cursor vazio."]); return end
    if not automatic then self.merchantAutoBlocked=nil end
    if MerchantFrame.selectedTab==2 and MerchantFrameTab1 then MerchantFrameTab1:Click() end
    self:Scan()
    self.merchantFailed=self.merchantFailed or {}
    if not automatic then self.merchantFailed={} end
    local queue={}
    for _,item in ipairs(self.items) do
        if item.storage=="bag" and item.action=="sell" and not self.merchantFailed[self:SaleKey(item)] then queue[#queue+1]={bag=item.bag,slot=item.slot,
            guid=item.guid,link=item.link,count=item.count,id=item.id} end
    end
    if #queue==0 then
        self.merchantAutoBlocked=true
        self.saleReport=L["Nenhum candidato disponível. Veja Manter, Revisar, Banco e AH na lista."]
        if not automatic then self:Print(self.saleReport) end
        self:RefreshUI();return
    end
    local inventory=self:CaptureSaleInventory()
    if not inventory then self:Print(L["Aguarde o carregamento completo da mochila."]); return end
    self.saleGeneration=(self.saleGeneration or 0)+1
    local state={queue=queue,total=#queue,index=0,sold=0,value=0,failed=0,skipped=0,inventory=inventory,
        batchLimit=12,retries={},
        generation=self.saleGeneration,mode=self:IsFullAuto() and "Full Auto" or "Semi Auto"}
    self.selling=state
    self.saleReport=nil
    self:Print(string.format(L["%s: %d pilhas elegíveis%s."],state.mode,#queue,self:IsFullAuto() and L["; venda até concluir"] or L["; até 12 por lote"]))
    self:NextSale(state)
end

function BM:FinishSelling(state,reason)
    if self.selling~=state then return end
    self.selling=nil
    if reason then self.merchantAutoBlocked=true end
    self.saleReport=string.format(L["%s: %d / %d vendidos%s%s"],state.mode,state.sold,state.total or #state.queue,
        state.failed>0 and " · "..state.failed..L[" bloqueados pelo jogo"] or "",
        reason and " · "..reason or state.skipped>0 and " · "..state.skipped..L[" retirados da fila após revalidação"] or L[" · Lote concluído"])
    if state.sold>0 then
        self:Print(string.format(L["%d pilhas vendidas por %s."],state.sold,self:Money(state.value)))
    end
    if reason then self:Print(reason)
    elseif state.failed>0 then self:Print(state.failed..L[" pilhas não foram vendidas pelo jogo; os demais candidatos foram processados. Clique Vender para tentar novamente."]) end
    self:Repair()
    self:Scan()
    self:Print(self:SaleRemainder())
    self.config.lastSale={mode=state.mode,sold=state.sold,planned=state.total or #state.queue,failed=state.failed,
        skipped=state.skipped,reason=reason,time=GetServerTime(),version=self.version}
    self:ScheduleScan()
end

function BM:NextSale(state)
    if self.selling~=state or state.generation~=self.saleGeneration or state.batch then return end
    if not self:CanUseMerchant() or self.config.pause then self:FinishSelling(state);return end
    if MerchantFrame.selectedTab==2 then self:FinishSelling(state,L["Recompra aberta; venda interrompida."]);return end
    if state.sold>=12 and not self:IsFullAuto() and state.index<#state.queue then
        self:FinishSelling(state,L["Limite do Semi Auto: 12 pilhas. Clique Vender ou autorize /bm full para continuar."]);return
    end
    if state.index>=#state.queue then self:FinishSelling(state);return end
    local inventory=self:CaptureSaleInventory()
    if not inventory then self:FinishSelling(state,L["Dados da mochila incompletos; aguarde e clique Vender."]);return end
    if state.needsScan or not inventoryMatches(state.inventory,inventory) then
        self:Scan();state.needsScan=nil;inventory=self:CaptureSaleInventory()
        if not inventory then self:FinishSelling(state,L["Mochila mudou durante a análise; aguarde e clique Vender."]);return end
    end
    state.inventory=inventory
    local limit=math.min(12,state.batchLimit)
    if not self:IsFullAuto() then limit=math.min(limit,12-state.sold) end
    local batch={entries={},before=self:Call(GetNumBuybackItems) or 0,issuing=true}
    state.batch=batch
    -- Submit a bounded native burst. Re-read every source before using it;
    -- never call Blizzard's unfiltered sell-all shortcut over protected items.
    while #batch.entries<limit and state.index<#state.queue do
        if not self:CanUseMerchant() or self.config.pause or state.needsScan then break end
        state.index=state.index+1
        local snapshot=state.queue[state.index]
        local position=inventory[snapshot.bag..":"..snapshot.slot]
        if snapshot.guid and (not position or position.guid~=snapshot.guid) then
            position=nil
            for _,entry in pairs(inventory) do if entry.guid==snapshot.guid then position=entry;break end end
        end
        local container=position and self:Call(C_Container.GetContainerItemInfo,position.bag,position.slot)
        local location=position and ItemLocation:CreateFromBagAndSlot(position.bag,position.slot)
        local guid=location and self:Call(C_Item.GetItemGUID,location)
        local valid=container and container.itemID==snapshot.id and container.hyperlink==snapshot.link
            and container.stackCount==snapshot.count and (not snapshot.guid or guid==snapshot.guid)
        if valid then
            local item=self:ReadItem(container.hyperlink,location,position.bag,position.slot,nil,container)
            item.storage="bag"
            item.action,item.reason=self:Classify(item)
            if item.action=="sell" then
                local entry={item=item,snapshot=snapshot}
                batch.entries[#batch.entries+1]=entry
                entry.ok=pcall(C_Container.UseContainerItem,item.bag,item.slot)
            else state.skipped=state.skipped+1 end
        else state.skipped=state.skipped+1 end
    end
    batch.issuing=false;batch.started=GetTime()
    if #batch.entries==0 then state.batch=nil;C_Timer.After(0,function() self:NextSale(state) end);return end
    self:RefreshUI();self:SaleUpdated()
end

function BM:SaleUpdated()
    local state=self.selling
    local batch=state and state.batch
    if not batch or batch.issuing or batch.scheduled then return end
    batch.scheduled=true
    -- Events wake confirmation immediately; the timer is only a fallback when
    -- the client does not deliver a bag/merchant event after a rejected burst.
    C_Timer.After(0,function()
        batch.scheduled=nil
        if self.selling==state and state.batch==batch then self:AcknowledgeSaleBatch(state,batch) end
    end)
end

function BM:AcknowledgeSaleBatch(state,batch)
    if self.selling~=state or state.batch~=batch or state.generation~=self.saleGeneration then return end
    if not self:CanUseMerchant() or self.config.pause then self:FinishSelling(state);return end
    if MerchantFrame.selectedTab==2 then self:FinishSelling(state,L["Recompra aberta; confira o último lote."]);return end
    local timeout=GetTime()-batch.started>=2
    local inventory=self:CaptureSaleInventory()
    if not inventory then
        if timeout then self:FinishSelling(state,L["Remoção da mochila não confirmada; confira a recompra."])
        else C_Timer.After(0.05,function() if state.batch==batch then self:SaleUpdated() end end) end
        return
    end
    local byGUID,linkDelta={},{}
    for _,entry in pairs(state.inventory) do linkDelta[entry.link or ""]=(linkDelta[entry.link or ""] or 0)+entry.count end
    for _,entry in pairs(inventory) do
        if entry.guid then byGUID[entry.guid]=entry end
        linkDelta[entry.link or ""]=(linkDelta[entry.link or ""] or 0)-entry.count
    end
    local gone,intact={},{}
    for _,entry in ipairs(batch.entries) do
        local item=entry.item
        local live=item.guid and byGUID[item.guid] or inventory[item.bag..":"..item.slot]
        local removed
        if item.guid then removed=byGUID[item.guid]==nil
        else
            removed=not identical(state.inventory[item.bag..":"..item.slot],live)
                and (linkDelta[item.link] or 0)>=item.count
            if removed then linkDelta[item.link]=linkDelta[item.link]-item.count end
        end
        if removed then gone[#gone+1]=entry
        elseif live and live.link==item.link and live.count==item.count then intact[#intact+1]=entry
        else
            self:FinishSelling(state,L["Quantidade/identidade mudou durante a venda; confira a recompra."]);return
        end
    end
    if #intact>0 and not timeout then
        C_Timer.After(0.05,function() if state.batch==batch then self:SaleUpdated() end end);return
    end
    -- A burst never exceeds the 12-entry receipt window. Confirm the trailing
    -- receipts in issue order, so historical entries alone cannot prove a sale.
    local count=self:Call(GetNumBuybackItems) or 0
    local receipts=count==math.min(12,batch.before+#gone) and count>=#gone
    if receipts then for i,entry in ipairs(gone) do
        local index=count-#gone+i
        local link=self:Call(GetBuybackItemLink,index)
        local _,_,price,quantity=self:Call(GetBuybackItemInfo,index)
        local item=entry.item
        if link~=item.link or price~=item.sellPrice*item.count or quantity~=item.count then receipts=false;break end
    end end
    if #gone>0 and not receipts then
        if timeout then self:FinishSelling(state,L["Lote sem confirmação completa na recompra; confira antes de continuar."])
        else C_Timer.After(0.05,function() if state.batch==batch then self:SaleUpdated() end end) end
        return
    end
    state.batch=nil
    for _,entry in ipairs(gone) do self:RecordConfirmedSale(state,entry.item,true) end
    -- Adapt to server throttling: retry refused intact items at most twice,
    -- first in smaller bursts and then singly. Never retry an ambiguous removal.
    for _,entry in ipairs(intact) do
        local saleKey=self:SaleKey(entry.item)
        local attempts=state.retries[saleKey] or 0
        if entry.ok and attempts<2 then
            state.retries[saleKey]=attempts+1
            state.queue[#state.queue+1]=entry.snapshot
            state.batchLimit=attempts==0 and math.min(state.batchLimit,4) or 1
        else
            self.merchantFailed[saleKey]=true;state.failed=state.failed+1
        end
    end
    self:RefreshUI()
    C_Timer.After(#intact>0 and 0.05 or 0,function() self:NextSale(state) end)
end

function BM:OpenBuyback()
    self.merchantAutoBlocked=true
    self:StopSelling()
    if not self:CanUseMerchant() then self:Print(L["Abra um vendedor para consultar a recompra."]); return end
    if MerchantFrameTab2 then MerchantFrameTab2:Click() end
    self:Print(L["Recompre os itens na aba do vendedor. As últimas 12 vendas ficam disponíveis enquanto o jogo permitir."])
end
