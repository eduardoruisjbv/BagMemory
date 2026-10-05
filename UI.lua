local _, BM = ...
local L=BM.L
local WHITE="Interface\\Buttons\\WHITE8X8"
local colors={bg={0.055,0.06,0.065,0.98},panel={0.09,0.10,0.11,1},row={0.115,0.125,0.135,1},
    text={0.93,0.90,0.83,1},muted={0.66,0.68,0.67,1},teal={0.29,0.82,0.75,1},
    amber={0.94,0.69,0.35,1},border={0.27,0.28,0.27,1}}
local actions={sell=L["À VENDA"],keep=L["MANTER"],review=L["REVISAR"],auction=L["AVALIAR AH"],bank=L["GUARDAR NO BANCO"],quest=L["INICIA MISSÃO"],warbank=L["SUGERIR BANCO DE GUERRA"]}

local function panel(parent,w,h,name)
    local frame=CreateFrame("Frame",name,parent,"BackdropTemplate")
    frame:SetSize(w,h)
    frame:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
    frame:SetBackdropColor(unpack(colors.panel))
    frame:SetBackdropBorderColor(unpack(colors.border))
    return frame
end
local function label(parent,text,x,y,w,font)
    local fs=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT",x,y); fs:SetWidth(w or 200); fs:SetJustifyH("LEFT")
    fs:SetTextColor(unpack(colors.text)); fs:SetText(text)
    return fs
end
local function tip(owner,title,text)
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    GameTooltip:AddLine(title,unpack(colors.teal))
    GameTooltip:AddLine(text,0.9,0.88,0.82,true); GameTooltip:Show()
end
local function button(parent,text,x,y,w,callback,primary)
    local f=CreateFrame("Button",nil,parent,"BackdropTemplate")
    f:SetSize(w,30); f:SetPoint("TOPLEFT",x,y)
    f:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
    f:SetBackdropColor(unpack(colors.row)); f:SetBackdropBorderColor(unpack(primary and colors.teal or colors.border))
    f.caption=label(f,text,6,-8,w-12,"GameFontNormal"); f.caption:SetJustifyH("CENTER")
    f:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    f:SetScript("OnClick",callback)
    f:SetScript("OnEnter",function() if f.tip then tip(f,text,f.tip) end end)
    f:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return f
end
local function checkbox(parent,title,key,x,y,description,width)
    local f=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    f:SetPoint("TOPLEFT",x,y); f:SetSize(26,26)
    label(f,title,29,-7,width or 214)
    f.key=key; f:SetScript("OnClick",function() BM:SetOption(key,f:GetChecked()==true) end)
    f:SetScript("OnEnter",function() tip(f,title,description) end)
    f:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return f
end

function BM:CreateUI()
    local ui=panel(UIParent,1060,690,"BagMemoryFrame"); self.ui=ui
    ui:SetBackdropColor(unpack(colors.bg)); ui:SetPoint("CENTER"); ui:SetFrameStrata("HIGH")
    ui:SetClampedToScreen(true); ui:SetMovable(true); ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton"); ui:SetScript("OnDragStart",ui.StartMoving)
    ui:SetScript("OnDragStop",ui.StopMovingOrSizing)
    ui:SetScale(math.min(1,(UIParent:GetWidth()-40)/1060,(UIParent:GetHeight()-40)/690))
    tinsert(UISpecialFrames,"BagMemoryFrame")
    label(ui,"BagMemory",22,-20,600,"GameFontNormalLarge")
    label(ui,L["Bag limpa. Seu melhor equipamento, preservado."],22,-48,740,"GameFontHighlight")
    local close=CreateFrame("Button",nil,ui,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5)
    ui.full=button(ui,L["Modo: Semi Auto"],778,-19,240,function()
        if self.config.fullAuto and self.config.fullAutoConsent==self.consentVersion then
            self.config.fullAuto=false; self.config.fullAutoConsent=nil
            self:StopAutomation(); self:ScheduleScan(); self:Print(L["Autorização do Full Auto revogada."])
        else self:ShowFullAutoConsent() end
    end,true)
    ui.context=label(ui,"",22,-77,1016,"GameFontHighlight")
    ui.season=label(ui,"",22,-100,1016); ui.season:SetTextColor(unpack(colors.muted))
    local rules=panel(ui,274,478); rules:SetPoint("TOPLEFT",22,-133)
    label(rules,L["REGRAS DESTE PERSONAGEM"],14,-13,246,"GameFontNormal"):SetTextColor(unpack(colors.teal))
    label(rules,L["Margem abaixo do ilvl equipado"],14,-43,246)
    ui.margin=label(rules,"",108,-76,70,"GameFontHighlight"); ui.margin:SetJustifyH("CENTER")
    button(rules,"−",14,-68,68,function() self:SetOption("margin",math.max(1,self.config.margin-1)) end)
    button(rules,"+",190,-68,68,function() self:SetOption("margin",math.min(100,self.config.margin+1)) end)
    ui.checks={}
    local entries={
        {L["Vender ao abrir vendedor"],"autoSell",L["Envia até 12 candidatos de uma vez. Semi Auto para após 12 vendas; Full Auto autorizado continua com os próximos lotes."]},
        {L["Limpar equipamentos inferiores"],"sellGear",L["Usa o ilvl equipado menos a margem, preservando os melhores de cada categoria nas bolsas e vestidos."]},
        {L["Vender quando a AH não compensa"],"lowMarket",L["Materiais e equipamentos negociáveis usam preços completos consultados na AH. Sem preço recente, são preservados."]},
        {L["Reparar automaticamente"],"autoRepair",L["Repara equipamentos ao abrir um NPC capaz, quando há dinheiro suficiente."]},
        {L["Usar reparo da guilda"],"guildRepair",L["Usa dinheiro da guilda se permitido e disponível; caso contrário, usa o personagem."]},
        {L["Dessaturar todos à venda"],"desaturate",L["Aplica o efeito a todos os candidatos nas bolsas e no banco do personagem nas interfaces padrão da Blizzard."]},
        {L["Preservar peças aprimoráveis"],"protectUpgradeable",L["Mantém itens que ainda aceitam melhorias. Desative para usar o ilvl atual dessas peças."]},
        {L["Organizar banco ao abrir"],"autoBank",L["Organiza mochila e banco do personagem. Full Auto também disponibiliza itens de missão na mochila."]}}
    for i,entry in ipairs(entries) do ui.checks[i]=checkbox(rules,entry[1],entry[2],10,-108-(i-1)*30,entry[3]) end
    label(rules,L["Lucro mínimo da AH por pilha"],14,-382,246)
    ui.profit=label(rules,"",95,-420,80,"GameFontHighlight"); ui.profit:SetJustifyH("CENTER")
    button(rules,"− 1g",14,-411,72,function() self:SetOption("marketProfit",math.max(0,self.config.marketProfit-1)) end)
    button(rules,"+ 1g",186,-411,72,function() self:SetOption("marketProfit",math.min(10000,self.config.marketProfit+1)) end)
    label(rules,L["Missões e equipamentos úteis protegidos."],14,-451,246):SetMaxLines(1)
    ui.summary=label(ui,"",316,-137,720,"GameFontHighlight")
    ui.search=CreateFrame("EditBox",nil,ui,"InputBoxTemplate")
    ui.search:SetSize(320,26); ui.search:SetPoint("TOPLEFT",324,-166); ui.search:SetAutoFocus(false)
    ui.search:SetScript("OnTextChanged",function() self:RefreshUI() end)
    ui.search:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
    ui.search:SetScript("OnEnter",function() tip(ui.search,L["Buscar item"],L["Digite parte do nome para filtrar a lista."]) end)
    ui.search:SetScript("OnLeave",function() GameTooltip:Hide() end)
    ui.filter="all"
    ui.filterButton=button(ui,L["Todos os itens"],658,-165,178,function()
        local filters={"all","sell","keep","review","auction","bank","quest","warbank"}
        for i,value in ipairs(filters) do if ui.filter==value then ui.filter=filters[i%#filters+1]; break end end
        ui.offset=0; self:RefreshUI()
    end)
    ui.mode=button(ui,"",848,-165,188,function() self:SetOption("pause",not self.config.pause) end)
    ui.scope="all"
    ui.scopeButton=button(ui,L["Todos os locais"],658,-198,178,function()
        ui.scope=ui.scope=="all" and "bag" or ui.scope=="bag" and "bank" or ui.scope=="bank" and "equipped" or "all"
        ui.offset=0; self:RefreshUI()
    end)
    ui.bank=button(ui,L["Organizar banco"],848,-198,188,function()
        self.bankBlocked={}; self:StartBankWork(false)
    end)
    ui.checks[#ui.checks+1]=checkbox(ui,L["Permitir venda de itens do Bando de Guerra"],
        "allowWarbandSale",316,-198,L["Ignora somente a proteção de vínculo ao Bando de Guerra/conta. O item segue as regras normais de venda; missões, heranças, melhores peças e proteções manuais continuam preservados."],302)
    label(ui,"ITEM / ILVL PVE · PVP",324,-225,310,"GameFontNormal"):SetTextColor(unpack(colors.teal))
    label(ui,L["DESTINO E MOTIVO"],634,-225,398,"GameFontNormal"):SetTextColor(unpack(colors.teal))
    ui.rows={}; ui.offset=0
    local list=panel(ui,720,324); list:SetPoint("TOPLEFT",316,-248)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel",function(_,delta)
        ui.offset=math.max(0,math.min(math.max(0,(ui.filteredCount or 0)-6),ui.offset-delta)); self:RefreshUI()
    end)
    for i=1,6 do
        local row=CreateFrame("Button",nil,list,"BackdropTemplate")
        row:SetSize(704,50); row:SetPoint("TOPLEFT",8,-8-(i-1)*52)
        row:SetBackdrop({bgFile=WHITE}); row:SetBackdropColor(unpack(colors.row))
        row:RegisterForClicks("LeftButtonUp","RightButtonUp")
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(36,36); row.icon:SetPoint("TOPLEFT",7,-7)
        row.name=label(row,"",51,-6,242,"GameFontHighlight"); row.name:SetMaxLines(1)
        row.level=label(row,"",51,-28,242); row.level:SetTextColor(unpack(colors.muted))
        row.action=label(row,"",310,-6,382,"GameFontNormal")
        row.reason=label(row,"",310,-25,382); row.reason:SetMaxLines(2)
        row:SetScript("OnEnter",function()
            if not row.item then return end
            GameTooltip:SetOwner(row,"ANCHOR_LEFT")
            if row.item.storage=="equipped" then GameTooltip:SetInventoryItem("player",row.item.inventorySlot)
            elseif row.item.storage=="bag" or row.item.liveBank then GameTooltip:SetBagItem(row.item.bag,row.item.slot)
            else GameTooltip:SetHyperlink(row.item.link) end
            GameTooltip:AddLine("BagMemory: "..row.item.reason,0.29,0.82,0.75,true)
            local quote=self:GetPrice(row.item)
            if quote then GameTooltip:AddLine("AH: "..self:Money(quote)..L[" por unidade (cotação, não venda garantida)"],0.9,0.88,0.82,true) end
            GameTooltip:AddLine(L["Clique: selecionar. Botão direito: guardar no banco. Shift+clique: link no chat."],0.66,0.68,0.67,true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnClick",function(_,mouseButton)
            if not row.item then return end
            if IsShiftKeyDown() and ChatEdit_InsertLink(row.item.link) then return end
            self.selected=row.item
            if mouseButton=="RightButton" then self:SetItemRule(row.item.id,"bank") end
            self:RefreshUI()
        end)
        ui.rows[i]=row
    end
    ui.page=label(ui,"",324,-582,480)
    button(ui,"↑",978,-576,27,function() ui.offset=math.max(0,ui.offset-6); self:RefreshUI() end)
    button(ui,"↓",1010,-576,27,function() ui.offset=math.min(math.max(0,(ui.filteredCount or 0)-6),ui.offset+6); self:RefreshUI() end)
    ui.selected=label(ui,L["Selecione um item para ajustar sua regra."],22,-625,260); ui.selected:SetMaxLines(2)
    ui.protect=button(ui,L["Proteger item"],316,-622,128,function() if self.selected then self:SetItemRule(self.selected.id,"keep") end end)
    ui.reset=button(ui,L["Automático"],450,-622,104,function() if self.selected then self:SetItemRule(self.selected.id,nil) end end)
    ui.manual=button(ui,L["Marcar venda"],560,-622,116,function()
        if self.selected then
            if self.selected.questStarter then self:StartQuestManually(self.selected)
            else self:SetItemRule(self.selected.id,"sell") end
        end
    end)
    ui.manual.tip=L["Aplica venda manual por ID; heranças, PvP, melhores da categoria e demais proteções continuam preservados."]
    ui.prepare=button(ui,L["Preparar na AH"],682,-622,144,function() if self.selected then self:PrepareAuction(self.selected) end end)
    ui.sell=button(ui,L["Vender"],832,-622,94,function() self:StartSelling() end,true)
    ui.buyback=button(ui,L["Recompra"],932,-622,104,function() self:OpenBuyback() end)
    ui.market=button(ui,L["Analisar AH"],22,-576,130,function()
        if self.marketScan then self:StopMarketScan() else self:StartMarketScan() end
    end)
    ui.refresh=button(ui,L["Atualizar"],166,-576,130,function() self:Scan() end)
    ui.status=label(ui,"",22,-667,1016); ui.status:SetTextColor(unpack(colors.muted))
    ui:Hide()
end

function BM:RefreshUI()
    local ui=self.ui
    if not ui or not ui:IsShown() or not self.config then return end
    local context=self.context or {}; local summary=self.summary or {}
    ui.context:SetText(string.format(L["Seu personagem  ·  Equipado: %.1f  |  Geral: %.1f  |  PvP equipado: %.1f  |  Faixa de venda: ≤ %.1f"],
        context.equipped or 0,context.total or 0,context.pvp or 0,context.cutoff or 0))
    ui.season:SetText(string.format(L["Temporada %s  ·  M+2: %s  ·  Banco: %s  ·  Melhores por categoria em PvE e PvP preservados."],
        context.season or L["indisponível"],context.seasonLevel and tostring(context.seasonLevel) or L["indisponível"],
        self.bankValidated and L["atualizado nesta sessão"] or L["abra para atualizar"]))
    ui.margin:SetText(self.config.margin..L[" níveis"]); ui.profit:SetText(self.config.marketProfit..L[" ouro"])
    for _,check in ipairs(ui.checks) do check:SetChecked(self.config[check.key]) end
    ui.summary:SetText(string.format(L["Venda %d · Banco %d · Guerra %d · Missões %d · Manter %d · Revisar %d · AH %d"],
        summary.sell or 0,summary.bank or 0,summary.warbank or 0,summary.quest or 0,summary.keep or 0,summary.review or 0,summary.auction or 0))
    ui.filterButton.caption:SetText(ui.filter=="all" and L["Todos os itens"] or actions[ui.filter])
    ui.mode.caption:SetText(self.config.pause and L["Automação pausada"] or L["Pausar automação"])
    ui.full.caption:SetText(self:IsFullAuto() and L["Modo: Full Auto"] or self.config.fullAuto and self.config.pause and L["Full Auto: pausado"] or L["Modo: Semi Auto"])
    ui.scopeButton.caption:SetText(ui.scope=="all" and L["Todos os locais"] or ui.scope=="bag" and L["Só mochila"] or ui.scope=="bank" and L["Só banco"] or L["Equipados"])
    ui.bank:SetEnabled(not not (self:CanUseBank() and not self.bankWork and not self.config.pause))
    local query=(ui.search:GetText() or ""):lower()
    local filtered={}
    for _,item in ipairs(self.items) do
        if (ui.filter=="all" or item.action==ui.filter) and (ui.scope=="all" or ui.scope==item.storage)
            and (query=="" or item.name:lower():find(query,1,true)) then filtered[#filtered+1]=item end
    end
    local order={sell=1,quest=2,warbank=3,bank=4,review=5,auction=6,keep=7}
    table.sort(filtered,function(a,b)
        if a.action~=b.action then return order[a.action]<order[b.action] end
        if a.name~=b.name then return a.name<b.name end
        return (a.bag or 100)*100+(a.slot or a.inventorySlot or 0)<(b.bag or 100)*100+(b.slot or b.inventorySlot or 0)
    end)
    ui.filteredCount=#filtered; ui.offset=math.min(ui.offset or 0,math.max(0,#filtered-6))
    for i,row in ipairs(ui.rows) do
        local item=filtered[i+ui.offset]; row.item=item; row:SetShown(item~=nil)
        if item then
            row.icon:SetTexture(item.icon or 134400); row.icon:SetDesaturated(item.action=="sell")
            row.name:SetText(item.name..(item.count>1 and " ×"..item.count or ""))
            local source=item.storage=="bank" and L["Banco"] or item.storage=="equipped" and L["Vestido"] or L["Mochila"]
            row.level:SetText(source.." · "..(item.gear and string.format("PvE %s · PvP %s",item.level or "?",item.pvpUnknown and "revisar" or (item.pvpLevel or item.level or "?"))
                or "NPC: "..self:Money((item.sellPrice or 0)*item.count)))
            row.action:SetText(actions[item.action]); row.action:SetTextColor(unpack(item.action=="sell" and colors.amber or colors.teal))
            row.reason:SetText(item.reason)
        end
    end
    ui.page:SetText(string.format(L["%d–%d de %d itens  ·  Role para navegar"],#filtered>0 and ui.offset+1 or 0,math.min(#filtered,ui.offset+6),#filtered))
    local item=self.selected
    ui.selected:SetText(item and item.name or L["Selecione um item para ajustar sua regra."])
    ui.protect:SetEnabled(item~=nil); ui.reset:SetEnabled(item~=nil); ui.manual:SetEnabled(item~=nil)
    ui.manual.caption:SetText(item and item.questStarter and L["Iniciar missão"] or L["Marcar venda"])
    ui.prepare:SetEnabled(item~=nil and item.storage=="bag" and self.ahOpen==true and item.bound==false and not item.account and not item.warband and not item.quest)
    ui.sell:SetEnabled(not not (not self.selling and not self.config.pause and self:CanUseMerchant() and (summary.bagSell or 0)>0))
    ui.buyback:SetEnabled(not not self:CanUseMerchant())
    ui.market:SetEnabled(self.ahOpen==true); ui.market.caption:SetText(self.marketScan and L["Parar AH"] or L["Analisar AH"])
    ui.status:SetText(self.bankWork and L["Transferindo no banco: "]..self.bankWork.index.." / "..#self.bankWork.queue
        or self.questWork and L["Iniciando e aceitando missão do item…"]
        or self.selling and string.format(L["%s: vendidas %d / %d pilhas · lotes rápidos de até 12"],self.selling.mode,self.selling.sold,self.selling.total or #self.selling.queue)
        or self.marketScan and L["Consultando AH: "]..self.marketScan.index.." / "..#self.marketScan.queue
        or self.merchantOpen and self.saleReport
        or string.format(L["Semi Auto: mochila/banco  ·  Full Auto: também missões de itens e venda contínua  ·  Beta %s"],self.version))
end

function BM:ShowFullAutoConsent()
    if not self.ui then self:CreateUI() end
    self.ui:Show()
    if not self.consent then
        local overlay=CreateFrame("Frame",nil,self.ui)
        overlay:SetAllPoints(self.ui); overlay:SetFrameLevel(self.ui:GetFrameLevel()+30); overlay:EnableMouse(true)
        local shade=overlay:CreateTexture(nil,"BACKGROUND"); shade:SetAllPoints(overlay); shade:SetColorTexture(0,0,0,0.8)
        local dialog=panel(overlay,620,450); dialog:SetPoint("CENTER")
        label(dialog,L["Autorizar Full Auto neste personagem"],22,-20,546,"GameFontNormalLarge")
        label(dialog,L["O addon executará as regras automaticamente quando os serviços do jogo estiverem acessíveis:\n\n• Gerenciar mochila e banco do personagem.\n• Vender todos os itens À venda e reparar.\n• Iniciar e aceitar missões oferecidas pelos itens.\n\nVendas além da recompra podem ser irreversíveis. Berloques, bônus de conjunto e itens protegidos exigem revisão. O jogo pode exigir confirmação ou interação manual em algumas operações."],22,-58,576,"GameFontHighlight"):SetSpacing(4)
        local check=CreateFrame("CheckButton",nil,dialog,"UICheckButtonTemplate")
        check:SetSize(26,26); check:SetPoint("TOPLEFT",18,-345)
        label(check,L["Autorizo o Full Auto e entendo as consequências das operações."],30,-5,550):SetMaxLines(2)
        local accept=button(dialog,L["Autorizar Full Auto"],22,-397,278,function()
            if check:GetChecked() then overlay:Hide(); self:AuthorizeFullAuto() end
        end,true)
        button(dialog,L["Cancelar"],312,-397,286,function() overlay:Hide() end)
        check:SetScript("OnClick",function() accept:SetEnabled(check:GetChecked()==true) end)
        overlay:SetScript("OnShow",function() check:SetChecked(false); accept:SetEnabled(false) end)
        overlay:Hide(); self.consent=overlay
    end
    self.consent:Show(); self:RefreshUI()
end

function BM:ToggleUI()
    if not self.ui then self:CreateUI() end
    if self.ui:IsShown() then self.ui:Hide() else self.ui:Show(); self:Scan() end
end
