local _, BM = ...
local L=BM.L

function BM:GetPrice(item)
    -- Commodities share a price by item ID; equipment variants are never mixed.
    local key=item.gear and item.link or tostring(item.id)
    local price=self.config.prices[key]
    if not price or not price.complete or price.realm~=GetRealmName()
        or GetServerTime()-price.time>self.config.marketAge*3600 then return nil end
    return price.unitPrice
end

function BM:LowMarketValue(item)
    local price=self:GetPrice(item)
    if not price or not item.sellPrice then return nil end
    -- Compare the entire stack after the AH's 5% cut; deposits lower profit further.
    return (price*0.95-item.sellPrice)*item.count<=self.config.marketProfit*10000
end

function BM:AppearanceStatus(item)
    if not item.gear or item.equipLoc=="INVTYPE_FINGER" or item.equipLoc=="INVTYPE_NECK"
        or item.equipLoc=="INVTYPE_TRINKET" then return true end
    local _,sourceID=self:Call(C_TransmogCollection and C_TransmogCollection.GetItemInfo,item.link)
    if not sourceID or sourceID==0 then return nil end
    local source=self:Call(C_TransmogCollection.GetAppearanceSourceInfo,sourceID)
    if type(source)~="table" then return nil end
    if source.isCollected==true then return true end
    return false
end

-- True only when the API confirms the item is not a toy, mount or pet. A failed
-- or restricted read is never permission to sell.
local function confirmedNotCollectible(item)
    if item.class==17 then return false end
    if item.class==15 and (item.subclass==2 or item.subclass==5 or item.subclass==6) then return false end
    if not item.id or not C_ToyBox or not C_ToyBox.GetToyInfo then return false end
    local ok,toy=pcall(C_ToyBox.GetToyInfo,item.id)
    if not ok or toy~=nil or (issecretvalue and issecretvalue(toy)) then return false end
    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local mountOk,mount=pcall(C_MountJournal.GetMountFromItem,item.id)
        if not mountOk or mount~=nil or (issecretvalue and issecretvalue(mount)) then return false end
    end
    return true
end

-- Non-gear items from earlier expansions: consumables, spare bags and
-- miscellaneous goods. Only items the vendor actually pays for, up to rare.
function BM:OldContentSale(item)
    local current=self.context and self.context.expansion
    if not current or not item.expansion or item.expansion>=current then return nil end
    if item.quality==nil or item.quality>3 or not item.sellPrice or item.sellPrice<=0 then return nil end
    -- PvP consumables scale by percentage, so they stay useful in any expansion.
    if item.pvp then return nil end
    if item.class==0 then
        if confirmedNotCollectible(item) then return L["Consumível de expansão anterior"] end
    elseif item.class==1 then
        -- A spare bag two or more expansions old is rarely larger than the equipped ones.
        if item.expansion<=current-2 then return L["Bolsa antiga guardada: expansão anterior"] end
    elseif item.class==15 then
        if confirmedNotCollectible(item) then return L["Item variado de expansão anterior"] end
    end
    return nil
end

-- A tier/set bonus is worth a limited level gap. Past it, the better item of the
-- same slot and context (PvP pieces are judged by their effective level) wins.
function BM:SetPieceObsolete(item)
    if not item.gear or not item.category then return false end
    -- PvP is judged only by its effective level; never fall back to the base one.
    if item.pvp and not item.pvpLevel then return false end
    local context=item.pvp and "pvp" or "pve"
    local slotBest=self.poolCut and self.poolCut[item.category] and self.poolCut[item.category][context]
    local level=item.pvp and (item.pvpLevel or item.level) or item.level
    if not slotBest or not level then return false end
    return level<=slotBest-(self.config.setTolerance or 25)
end

function BM:Classify(item)
    if item.pending or not item.id or item.quality==nil then return "review",L["Dados do item ainda carregando"] end
    if item.storage=="equipped" then return "keep",L["Equipado: preservado e usado na comparação da categoria"] end
    -- Mission protection always precedes manual sale and value-based rules.
    if item.quest or item.questStarter or item.class==12 or item.bindType==4 then
        if item.questActive then return "keep",L["Missão ativa: manter disponível na mochila"] end
        if item.questStarter and item.questOnLog~=true and not item.questCompleted then
            return "quest",L["Inicia missão: protegido; Full Auto tenta iniciar e aceitar"]
        end
        if item.questID and item.questOnLog==false and item.questCompleted==true then
            return "bank",L["Item de missão concluída: guardar se o banco permitir"]
        end
        return "keep",L["Item de missão protegido; necessidade ou destino ainda não confirmado"]
    end
    if item.quality==7 then return "keep",L["Herança: sempre preservada"] end
    if item.gear and item.crafted then return "keep",L["Item fabricado: pode ser reforjado"] end
    if item.quality>=5 then return "keep",L["Lendário, artefato ou item especial"] end
    if item.questUnknown then return "review",L["Dados de missão não confirmados"] end
    if item.tooltipUnknown then return "review",L["Descrição do item não confirmada; missão ou utilidade pode estar pendente"] end
    if item.refundable==nil or item.bound==nil then return "review",L["Vínculo ou reembolso não confirmado"] end
    if item.refundable then return "keep",L["Ainda pode ser reembolsado"] end
    if self.config.rules[item.id]=="keep" then return "keep",L["Proteção manual neste personagem"] end
    if (item.account or item.warband) and not self.config.allowWarbandSale then
        return "warbank",L["Bando de Guerra/conta: proteção de venda ativa"]
    end
    -- Account/warband bindings are not auctionable even before soulbinding.
    -- With the bypass enabled they follow the ordinary bound-item sale rules.
    local tradeBound=item.bound or item.account or item.warband
    if item.specialBinding then return "keep",L["Ainda trocável: item protegido"] end
    if self.setItems[item.id] and not self:SetPieceObsolete(item) then
        return "keep",L["Pertence a um conjunto de equipamento salvo"]
    end
    if item.storage=="bank" and not self.bankValidated then
        return "review",L["Registro do banco: abra o banco para atualizar a classificação"]
    end
    if item.gear and item.classSuitable==false then
        if item.sellPrice==nil then return "review",L["Equipamento incompatível; valor de venda não confirmado"] end
        if item.locked then return "review",L["Equipamento incompatível em movimentação"] end
        if self.config.rules[item.id]=="bank" or item.noValue or item.sellPrice<=0 then
            return "bank",L["Não serve à classe; guardar no banco se desejado"]
        end
        if not self.config.sellGear then return "review",L["Não serve à classe; limpeza de equipamento desativada"] end
        if tradeBound or item.quality==0 or self.config.rules[item.id]=="sell" then
            return "sell",L["Não serve à classe do personagem; ilvl, PvP e melhorias não tornam a peça útil"]
        end
        if self.config.lowMarket and self:LowMarketValue(item)==true then return "sell",L["Não serve à classe e AH não compensa"] end
        return "auction",L["Não serve à classe; negociável, avaliar valor na AH"]
    end
    if item.gear then
        if self.equipmentIncomplete or self.setsUnknown or self.incompleteCategories[item.category] then
            return "review",L["Comparação incompleta; aguarde os dados dos equipamentos"]
        end
        local best=self.bestItems[item.guid or item.link]
        if best then
            return "keep",best.pvp and L["Entre os melhores da categoria em PvP (ilvl efetivo)"] or L["Entre os melhores da categoria em PvE"]
        end
        if item.setID and item.setID>0 and not self:SetPieceObsolete(item) then
            return "keep",L["Peça de conjunto: bônus pode ser útil"]
        end
        if item.equipLoc=="INVTYPE_TRINKET" then return "keep",L["Berloque: efeitos precisam de comparação manual"] end
        local appearance=self:AppearanceStatus(item)
        if appearance==nil then return "review",L["Coleta da aparência não confirmada"] end
        if not appearance then return "keep",L["Aparência ainda não coletada"] end
        if self.config.protectUpgradeable and item.upgradeable~=false then
            return "keep",L["Pode receber melhorias ou melhoria ainda não confirmada"]
        end
        -- The best of the carried/worn items is protected even with a closed
        -- bank. Unseen bank items can only add better alternatives, never turn
        -- an already inferior carried item into the character's best item.
    end
    if item.sellPrice==nil then return "review",L["Valor de venda não confirmado"] end
    if item.noValue or item.sellPrice<=0 then
        if item.useSpell or item.class==0 or self.professionSlots[item.equipLoc] then
            return "keep",L["Sem valor de venda; item de uso ou utilidade preservado"]
        end
        return "bank",L["Sem valor de venda: sugerido para guardar no banco"]
    end
    if item.locked then return "review",L["Item bloqueado ou em movimentação"] end
    if self.config.rules[item.id]=="bank" then return "bank",L["Guardar no banco: escolha manual"] end
    if self.config.rules[item.id]=="sell" then return "sell",L["Regra manual de venda"] end
    if item.quality==0 then
        if item.gear then
            -- Gear has already passed appearance and category protection above.
            return "sell",L["Lixo; aparência coletada e alternativas preservadas"]
        end
        return "sell",L["Lixo de qualidade cinza"]
    end
    if item.gear then
        -- PvP gear is judged only against PvP gear, at its effective (scaled) level.
        if item.pvp and not item.pvpLevel then return "review",L["PvP sem ilvl efetivo legível; não é julgado pelo ilvl base"] end
        local level=item.pvp and item.pvpLevel or item.level
        local context=item.pvp and "pvp" or "pve"
        -- The protected band is measured against the best item of the same slot
        -- and context. Only when no such reference exists does the character's
        -- average level stand in for it.
        local slotBest=self.poolCut and self.poolCut[item.category] and self.poolCut[item.category][context]
        local cutoff
        if slotBest then cutoff=slotBest-self.config.margin
        else cutoff=item.pvp and self.context.pvpCutoff or self.context.cutoff end
        if not cutoff or not level then return "review",L["Ilvl do personagem ou item indisponível"] end
        if level>cutoff then
            return "keep",string.format(L["Perto do melhor do slot em %s: ilvl %s > %.1f"],item.pvp and "PvP" or "PvE",level,cutoff)
        end
        if not self.config.sellGear then return "review",L["Equipamento inferior; venda automática de equipamento desativada"] end
        if not tradeBound then
            if self.config.lowMarket and self:LowMarketValue(item)==true then
                return "sell",L["Equipamento inferior e AH com retorno baixo"]
            end
            return "auction",L["Equipamento negociável: avaliar na AH"]
        end
        local old=item.expansion and self.context.expansion and item.expansion<self.context.expansion
        return "sell",string.format(L["%s%s: ilvl %d ≤ %.1f; melhores da categoria preservados"],
            old and L["Equipamento de expansão antiga"] or L["Equipamento inferior"],item.pvp and " (PvP)" or "",level,cutoff)
    end
    local oldReason=self:OldContentSale(item)
    if oldReason then return "sell",oldReason end
    -- Materials can be valuable from any expansion. Unknown AH value means keep,
    -- except common and uncommon materials from earlier expansions.
    if item.reagent or item.class==7 then
        local current=self.context and self.context.expansion
        if current and item.expansion and item.expansion<current and item.quality and item.quality<=2
            and item.sellPrice and item.sellPrice>0 and not (item.account or item.warband) then
            local known=self:GetPrice(item)
            if known==nil or self:LowMarketValue(item)==true then
                return "sell",L["Material comum de expansão anterior"]..(known and L[" e AH não compensa"] or "")
            end
        end
        if item.account or item.warband then
            return "keep",L["Material do Bando de Guerra/conta: preservado; não pode ser negociado na AH"]
        end
        if not item.bound and self.config.lowMarket and self:LowMarketValue(item)==true then
            return "sell",L["AH não compensa: lucro da pilha abaixo do limite"]
        end
        return "auction",self:GetPrice(item) and L["Material com valor na AH"] or L["Material preservado; preço da AH não confirmado"]
    end
    return "keep",L["Consumível, receita, colecionável ou utilidade preservada"]
end
