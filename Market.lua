local _, BM = ...
local L=BM.L
local function keyString(key)
    return table.concat({key.itemID or 0,key.itemLevel or 0,key.itemSuffix or 0,key.battlePetSpeciesID or 0},":")
end

function BM:StopMarketScan()
    self.marketGeneration=(self.marketGeneration or 0)+1
    self.marketScan=nil
    self:RefreshUI()
end

function BM:StartMarketScan()
    if not self.ahOpen then self:Print(L["Abra a Casa de Leilões para consultar preços reais."]); return end
    if self.marketScan then return end
    self:Scan()
    local queue,seen={},{}
    for _,item in ipairs(self.items) do
        if item.storage=="bag" and item.bound==false and not item.quest and not item.questStarter and not item.account and not item.warband and not item.pending
            and (item.action=="auction" or item.reagent or item.class==7)
            and self:Call(C_AuctionHouse.IsSellItemValid,item.location) then
            local key=self:Call(C_AuctionHouse.GetItemKeyFromItem,item.location)
            if key then
                local id=keyString(key)
                if not seen[id] then
                    local status=self:Call(C_AuctionHouse.GetItemCommodityStatus,item.location)
                    if status==Enum.ItemCommodityStatus.Commodity or status==Enum.ItemCommodityStatus.Item then
                        seen[id]=true
                        queue[#queue+1]={key=key,id=id,commodity=status==Enum.ItemCommodityStatus.Commodity,
                            cacheKey=item.gear and item.link or tostring(item.id),name=item.name}
                    end
                end
            end
        end
    end
    self.marketGeneration=(self.marketGeneration or 0)+1
    local state={queue=queue,index=0,generation=self.marketGeneration,done=0}
    self.marketScan=state
    self:NextMarketQuery(state)
end

function BM:NextMarketQuery(state)
    if self.marketScan~=state or state.generation~=self.marketGeneration or not self.ahOpen then return end
    state.index=state.index+1
    state.started=nil
    state.current=state.queue[state.index]
    if not state.current then
        self.marketScan=nil
        self:Print(string.format(L["AH: %d preços confirmados; itens sem ofertas continuam preservados."],state.done))
        self:ScheduleScan()
        return
    end
    local function send()
        if self.marketScan~=state or not self.ahOpen then return end
        if not self:Call(C_AuctionHouse.IsThrottledMessageSystemReady) then
            C_Timer.After(1.2,send); return
        end
        state.started=GetTime(); state.requestedMore=nil
        C_AuctionHouse.SendSearchQuery(state.current.key,{},true)
        self:RefreshUI()
        local current=state.current
        C_Timer.After(25,function()
            if self.marketScan==state and state.current==current then
                self:NextMarketQuery(state)
            end
        end)
    end
    C_Timer.After(1.2,send)
end

function BM:MarketResults(event,key)
    local state=self.marketScan
    if not state or not state.current or not self.ahOpen or not state.started then return end
    local current=state.current
    if current.commodity then
        if event~="COMMODITY_SEARCH_RESULTS_UPDATED" or key~=current.key.itemID then return end
    elseif event~="ITEM_SEARCH_RESULTS_UPDATED" or type(key)~="table" or keyString(key)~=current.id then return end
    local complete
    if current.commodity then complete=self:Call(C_AuctionHouse.HasFullCommoditySearchResults,current.key.itemID)
    else complete=self:Call(C_AuctionHouse.HasFullItemSearchResults,current.key) end
    if complete~=true then
        if not state.requestedMore then
            state.requestedMore=true
            C_Timer.After(1.2,function()
                if self.marketScan~=state or state.current~=current or not self.ahOpen then return end
                if self:Call(C_AuctionHouse.IsThrottledMessageSystemReady) then
                    if current.commodity then C_AuctionHouse.RequestMoreCommoditySearchResults(current.key.itemID)
                    else C_AuctionHouse.RequestMoreItemSearchResults(current.key) end
                end
                state.requestedMore=nil
            end)
        end
        return
    end
    local count
    if current.commodity then count=self:Call(C_AuctionHouse.GetNumCommoditySearchResults,current.key.itemID)
    else count=self:Call(C_AuctionHouse.GetNumItemSearchResults,current.key) end
    local lowest
    for index=1,(count or 0) do
        local result
        if current.commodity then result=self:Call(C_AuctionHouse.GetCommoditySearchResultInfo,current.key.itemID,index)
        else result=self:Call(C_AuctionHouse.GetItemSearchResultInfo,current.key,index) end
        if result and not result.containsOwnerItem then
            local price=current.commodity and result.unitPrice or result.buyoutAmount
            if type(price)=="number" and (not issecretvalue or not issecretvalue(price)) and price>0 then
                if not current.commodity then price=price/math.max(1,result.quantity or 1) end
                lowest=not lowest and price or math.min(lowest,price)
            end
        end
    end
    if lowest then
        self.config.prices[current.cacheKey]={unitPrice=lowest,time=GetServerTime(),
            complete=true,realm=GetRealmName()}
        state.done=state.done+1
    else
        -- A now-empty market invalidates an earlier cheap quote.
        self.config.prices[current.cacheKey]=nil
    end
    state.started=nil
    self:ScheduleScan()
    self:NextMarketQuery(state)
end

function BM:PrepareAuction(item)
    if not self.ahOpen or not AuctionHouseFrame or not AuctionHouseFrame.SetPostItem then
        self:Print(L["Abra a Casa de Leilões para preparar um anúncio."]); return
    end
    self:StopMarketScan()
    self:Scan()
    local live=self.bySlot[item.bag..":"..item.slot]
    if not live or live.link~=item.link or (item.guid and live.guid~=item.guid)
        or live.bound~=false or live.account or live.warband
        or not self:Call(C_AuctionHouse.IsSellItemValid,live.location) then
        self:Print(L["O item mudou ou não pode ser anunciado."]); return
    end
    AuctionHouseFrame:SetPostItem(live.location)
    if self.ui then self.ui:Hide() end
    self:Print(L["Item preparado. Confira preço, quantidade e depósito e clique em Anunciar na janela da AH."])
end
