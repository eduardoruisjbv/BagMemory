local _, BM = ...
local L=BM.L
local normalize = {INVTYPE_ROBE="INVTYPE_CHEST", INVTYPE_RANGEDRIGHT="INVTYPE_RANGED"}
local professionSlots = {INVTYPE_PROFESSION_TOOL=true, INVTYPE_PROFESSION_GEAR=true,
    INVTYPE_BAG=true, INVTYPE_TABARD=true, INVTYPE_BODY=true}
BM.professionSlots = professionSlots
local textFields={"leftText","rightText"}
local bindingGlobals={"BIND_TRADE_TIME_REMAINING", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND",
    "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP"}
local tooltipLabels
local statGroups={
    ITEM_MOD_STRENGTH_SHORT="str",ITEM_MOD_AGILITY_SHORT="agi",ITEM_MOD_INTELLECT_SHORT="int",
    ITEM_MOD_AGI_STR_INT_SHORT="agi-int-str",ITEM_MOD_AGI_STR_SHORT="agi-str",
    ITEM_MOD_AGI_INT_SHORT="agi-int",ITEM_MOD_STR_INT_SHORT="int-str"}

local function clean(text)
    return type(text)=="string" and text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " ") or ""
end

-- Match Blizzard's localized PvP tooltip rather than assuming an English client.
local function formatPattern(text)
    if type(text)~="string" then return end
    text = clean(text):gsub("%%1%$d", "@@LEVEL@@"):gsub("%%d", "@@LEVEL@@")
    if not text:find("@@LEVEL@@",1,true) then return end
    text = text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    return text:gsub("@@LEVEL@@", "(%%d+)")
end

function BM:ReadTooltip(item)
    -- Cache only localized constants. Item bindings, quest flags, refunds and
    -- tooltip contents are deliberately read live for every classification.
    if not tooltipLabels then
        tooltipLabels={pvp=formatPattern(PVP_ITEM_LEVEL_TOOLTIP),
            startsQuest=clean(ITEM_STARTS_QUEST),quest=clean(ITEM_BIND_QUEST),bindings={},
            createdBy=(clean(ITEM_CREATED_BY):match("^(.-)%%") or "")}
        for _,global in ipairs(bindingGlobals) do
            local raw=clean(_G[global])
            local label=raw:match("^(.-)%%")
            if not label or label=="" then label=raw end
            if label~="" then tooltipLabels.bindings[#tooltipLabels.bindings+1]={label=label,trade=global=="BIND_TRADE_TIME_REMAINING"} end
        end
    end
    local data
    if C_TooltipInfo then
        if item.bag then data=self:Call(C_TooltipInfo.GetBagItem,item.bag,item.slot)
        else data=self:Call(C_TooltipInfo.GetInventoryItem,"player",item.inventorySlot) end
    end
    if not data or type(data.lines)~="table" or #data.lines==0 then
        item.tooltipUnknown=true
        return
    end
    local pattern = tooltipLabels.pvp
    for _,line in ipairs(data.lines) do
        for _,field in ipairs(textFields) do
            local raw=line[field]
            if issecretvalue and issecretvalue(raw) then item.tooltipUnknown=true; return end
            local text=clean(raw)
            if tooltipLabels.startsQuest~="" and text==tooltipLabels.startsQuest then item.questStarter=true; item.quest=true end
            if tooltipLabels.quest~="" and text==tooltipLabels.quest then item.quest=true end
            if tooltipLabels.createdBy~="" and text:find(tooltipLabels.createdBy,1,true) then item.crafted=true end
            local level=pattern and tonumber(text:match(pattern))
            if level and level>0 then item.pvp=true; item.pvpLevel=math.max(item.level or 0,level) end
            local lower=text:lower()
            if lower:find("pvp",1,true) or lower:find("jogador contra jogador",1,true)
                or lower:find("arenas",1,true) or lower:find("battleground",1,true)
                or lower:find("campos de batalha",1,true) then item.pvp=true end
            for _,binding in ipairs(tooltipLabels.bindings) do
                if text:find(binding.label,1,true) then
                    if binding.trade then item.specialBinding=true
                    else item.warband=true end
                end
            end
        end
    end
    local stats=self:Call(C_Item.GetItemStats,item.link)
    item.stats=stats
    if type(stats)=="table" then
        if stats.ITEM_MOD_PVP_POWER_SHORT or stats.ITEM_MOD_PVP_RESILIENCE_RATING_SHORT
            or stats.ITEM_MOD_RESILIENCE_RATING_SHORT then item.pvp=true end
    end
    if item.pvp and not item.pvpLevel then item.pvpUnknown=true end
end

function BM:ReadItem(link, location, bag, slot, inventorySlot, container)
    local info={self:Call(C_Item.GetItemInfo,link)}
    local item={link=link, location=location, bag=bag, slot=slot, inventorySlot=inventorySlot,
        id=container and container.itemID or self:Call(C_Item.GetItemID,location),
        count=container and container.stackCount or 1,
        locked=container and container.isLocked, noValue=container and container.hasNoValue}
    item.guid=self:Call(C_Item.GetItemGUID,location)
    if not info[1] then
        item.name=L["Carregando item"]; item.pending=true
        if item.id and not self.waitingItems[item.id] then
            self.waitingItems[item.id]=true
            self:Call(C_Item.RequestLoadItemDataByID,item.id)
        end
        return item
    end
    if item.id then self.waitingItems[item.id]=nil end
    item.name,item.quality,item.baseLevel=info[1],info[3],info[4]
    item.minLevel=info[5]
    item.equipLoc,item.icon,item.sellPrice=info[9],info[10],info[11]
    item.class,item.subclass,item.bindType=info[12],info[13],info[14]
    item.expansion,item.setID,item.reagent=info[15],info[16],info[17]
    item.level=self:Call(C_Item.GetCurrentItemLevel,location) or self:Call(C_Item.GetDetailedItemLevelInfo,link)
    item.bound=self:Call(C_Item.IsBound,location)
    if item.bound==nil and container then item.bound=container.isBound end
    item.refundable=self:Call(C_Item.CanBeRefunded,location)
    item.account=self:Call(C_Item.IsBoundToAccountUntilEquip,location)
    if bag then
        local quest=self:Call(C_Container.GetContainerItemQuestInfo,bag,slot)
        item.quest=type(quest)=="table" and (quest.isQuestItem or quest.questID~=nil)
        item.questUnknown=type(quest)~="table"
        if type(quest)=="table" then
            item.questID=quest.questID
            item.questActive=quest.isActive==true
            item.questStarter=quest.questID~=nil and quest.isActive==false
        end
    end
    if item.class==12 or item.bindType==4 then item.quest=true end
    self:ReadTooltip(item)
    if item.questID then
        local onQuest=self:Call(C_QuestLog and C_QuestLog.IsOnQuest,item.questID)
        item.questOnLog=onQuest
        item.questActive=item.questActive or onQuest==true
        item.questCompleted=self:Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,item.questID)
    end
    if self.questNeededItems and self.questNeededItems[item.id] then item.quest=true; item.questActive=true end
    local _,spellID=self:Call(C_Item.GetItemSpell,item.link)
    item.useSpell=spellID
    item.gear=(item.class==2 or item.class==4) and item.equipLoc and item.equipLoc~=""
        and not professionSlots[item.equipLoc]
    if item.gear then
        -- Crafted gear can be recrafted, so it is never treated as disposable.
        if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo
            and self:Call(C_TradeSkillUI.GetItemCraftedQualityByItemInfo,link) then item.crafted=true end
        item.classSuitable=self:GearClassSuitable(item)
        local category=normalize[item.equipLoc] or item.equipLoc
        -- Preserve alternate weapon types and armor types, not just the current spec.
        local primary={}
        for stat,value in pairs(item.stats or {}) do
            if statGroups[stat] and type(value)=="number" and value>0 then primary[#primary+1]=statGroups[stat] end
        end
        table.sort(primary)
        item.category=category..":"..tostring(item.subclass)..":"..table.concat(primary,"+")
        item.capacity=(category=="INVTYPE_FINGER" or category=="INVTYPE_TRINKET"
            or category=="INVTYPE_WEAPON" or category=="INVTYPE_2HWEAPON") and 2 or 1
        item.upgradeable=self:Call(C_ItemUpgrade and C_ItemUpgrade.CanUpgradeItem,location)
    end
    return item
end

function BM:BuildBestItems(allItems)
    self.bestItems, self.incompleteCategories, self.poolCut = {}, {}, {}
    local groups={}
    self.equipmentIncomplete=false
    for _,item in ipairs(allItems) do
        local usableRecord=item.storage~="bank" or self.bankValidated
        if item.pending and usableRecord then self.equipmentIncomplete=true end
        if item.category and usableRecord and item.classSuitable~=false then
            local list=groups[item.category] or {}; groups[item.category]=list
            list[#list+1]=item
            -- An item whose PvP scaling is unreadable only affects itself; it is
            -- ranked by its base level and never blocks the rest of the category.
            if not item.level or item.tooltipUnknown then
                self.incompleteCategories[item.category]=true
            end
        end
    end
    -- PvE items compete only with PvE items by their base item level. PvP items
    -- compete only with PvP items by their effective (PvP-scaled) level.
    for category,list in pairs(groups) do
        for _,context in ipairs({"pve","pvp"}) do
            local pool={}
            for _,item in ipairs(list) do
                if (context=="pvp")==(item.pvp==true) then pool[#pool+1]=item end
            end
            if #pool>0 then
                local function level(item) return context=="pvp" and (item.pvpLevel or item.level or 0) or (item.level or 0) end
                table.sort(pool,function(a,b) return level(a)>level(b) end)
                local edge=pool[math.min(#pool,pool[1].capacity)]
                local cut=level(edge)
                -- Weakest level that still counts as "best" in this slot and context.
                self.poolCut[category]=self.poolCut[category] or {}
                self.poolCut[category][context]=cut
                for _,item in ipairs(pool) do
                    if level(item)>=cut then
                        local key=item.guid or item.link
                        self.bestItems[key]=self.bestItems[key] or {}
                        self.bestItems[key][context]=true
                    end
                end
            end
        end
    end
end

function BM:Scan()
    if not self.db then return end
    local _,class=self:Call(UnitClass,"player");self.playerClass=class
    self:ReadQuestNeeds()
    local total,equipped,pvp=self:Call(GetAverageItemLevel)
    self.context={total=total, equipped=equipped, pvp=pvp,
        cutoff=equipped and equipped>0 and math.floor((equipped-self.config.margin)*100)/100 or nil,
        pvpCutoff=pvp and pvp>0 and math.floor((pvp-self.config.margin)*100)/100 or nil,
        expansion=self:Call(C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonExpansion)
            or LE_EXPANSION_LEVEL_CURRENT,
        season=self:Call(C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID)}
    local _,seasonLevel=self:Call(C_MythicPlus and C_MythicPlus.GetRewardLevelForDifficultyLevel,2)
    self.context.seasonLevel=seasonLevel and seasonLevel>0 and seasonLevel or nil
    self.setItems={}
    local ids=self:Call(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs)
    self.setsUnknown=type(ids)~="table"
    for _,setID in ipairs(ids or {}) do
        local setItems=self:Call(C_EquipmentSet.GetItemIDs,setID)
        if not setItems then self.setsUnknown=true end
        for _,id in pairs(setItems or {}) do if id and id>0 then self.setItems[id]=true end end
    end
    local items,all,bySlot={},{},{}
    for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local container=self:Call(C_Container.GetContainerItemInfo,bag,slot)
            if container then
                local location=ItemLocation:CreateFromBagAndSlot(bag,slot)
                local item=self:ReadItem(container.hyperlink or container.itemID,location,bag,slot,nil,container)
                item.storage="bag"
                items[#items+1]=item; all[#all+1]=item; bySlot[bag..":"..slot]=item
            end
        end
    end
    local bankItems=self:ReadBankItems()
    for _,item in ipairs(bankItems) do
        items[#items+1]=item; all[#all+1]=item
        if item.liveBank then bySlot[item.bag..":"..item.slot]=item end
    end
    for _,item in ipairs(self:ReadWarbandItems()) do
        items[#items+1]=item; all[#all+1]=item
        bySlot[item.bag..":"..item.slot]=item
    end
    self.worn={}
    for slot=1,19 do
        local link=self:Call(GetInventoryItemLink,"player",slot)
        if link then
            local item=self:ReadItem(link,ItemLocation:CreateFromEquipmentSlot(slot),nil,nil,slot)
            item.storage="equipped"; self.worn[slot]=item; all[#all+1]=item; items[#items+1]=item
        elseif self:Call(GetInventoryItemID,"player",slot) then all[#all+1]={pending=true} end
    end
    self:BuildBestItems(all)
    local summary={sell=0,keep=0,review=0,auction=0,bank=0,quest=0,value=0,bagSell=0}
    for _,item in ipairs(items) do
        item.action,item.reason=self:Classify(item)
        summary[item.action]=(summary[item.action] or 0)+1
        if item.action=="sell" then
            summary.value=summary.value+(item.sellPrice or 0)*item.count
            if item.storage=="bag" then summary.bagSell=summary.bagSell+1 end
        end
    end
    self.items,self.bySlot,self.summary=items,bySlot,summary
    -- Plain-data dump of the last classification, readable from SavedVariables.
    local dump={at=GetServerTime(),bankValidated=self.bankValidated,equipmentIncomplete=self.equipmentIncomplete,
        setsUnknown=self.setsUnknown,context=self.context and {expansion=self.context.expansion,
        cutoff=self.context.cutoff,pvpCutoff=self.context.pvpCutoff,equipped=self.context.equipped,
        pvp=self.context.pvp} or nil,items={}}
    for _,item in ipairs(items) do
        if item.storage~="equipped" and #dump.items<400 then
            dump.items[#dump.items+1]={name=item.name,storage=item.storage,action=item.action,reason=item.reason,
                class=item.class,quality=item.quality,level=item.level,pvp=item.pvp,pvpLevel=item.pvpLevel,
                category=item.category,bound=item.bound,account=item.account,warband=item.warband,
                expansion=item.expansion,appearance=item.gear and ({[true]="coletada",[false]="nao coletada"})[self:AppearanceStatus(item)] or (item.gear and "desconhecida" or nil),
                incompleteCategory=item.category and self.incompleteCategories[item.category] or nil,
                tooltipUnknown=item.tooltipUnknown,pvpUnknown=item.pvpUnknown,refundable=item.refundable}
        end
    end
    self.db.lastScan=dump
    self:RefreshBagIcons()
    self:RefreshUI()
end
