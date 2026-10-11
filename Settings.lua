local _, BM = ...
local L = BM.L

local function RegisterSettingsCategory()
    if BM.settingsCategory then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory
        and Settings.RegisterAddOnSetting and Settings.CreateCheckbox) then
        return
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory("BagMemory")
    local function Header(title)
        if layout and CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
        end
    end
    local function Note(body)
        if layout and CreateSettingsListTextEntryInitializer then
            layout:AddInitializer(CreateSettingsListTextEntryInitializer(body))
        end
    end
    local function Checkbox(key, label, tooltip)
        local variable = "BagMemory_" .. key
        local setting = Settings.RegisterAddOnSetting(
            category, variable, key, BM.config, Settings.VarType.Boolean, label, BM.defaults[key]
        )
        setting:SetValueChangedCallback(function()
            if BM.config then BM:SetOption(key, setting:GetValue()) end
            if BM.RefreshUI then BM:RefreshUI() end
        end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    Header("BagMemory")
    Note("Configure character-specific rules here. Type /bm to open the item review and management window. Full Auto remains a separate opt-in that requires explicit confirmation.")
    Header("Automation")
    Checkbox("pause", L["Pausar automação"], L["Interrompe as operações automáticas deste personagem."])
    Checkbox("autoSell", L["Vender ao abrir vendedor"], L["Envia candidatos em lotes; Full Auto autorizado pode continuar com os próximos lotes."])
    Checkbox("autoRepair", L["Reparar automaticamente"], L["Repara ao abrir um NPC capaz, quando há dinheiro suficiente."])
    Checkbox("guildRepair", L["Usar reparo da guilda"], L["Usa fundos da guilda se permitido e disponível."])
    Checkbox("autoBank", L["Organizar banco ao abrir"], L["Organiza mochila e banco do personagem quando o banco abre."])
    Header("Item protection")
    Checkbox("sellGear", L["Limpar equipamentos inferiores"], L["Usa o ilvl equipado menos a margem e preserva as melhores peças."])
    Checkbox("protectUpgradeable", L["Preservar peças aprimoráveis"], L["Mantém itens que ainda aceitam melhorias."])
    Checkbox("allowWarbandSale", L["Permitir venda de itens do Bando de Guerra"], L["Ignora somente a proteção de vínculo ao Bando de Guerra/conta; as demais proteções continuam ativas."])
    Header("Market and appearance")
    Checkbox("lowMarket", L["Vender quando a AH não compensa"], L["Compara valores com preços recentes observados na AH; sem cotação recente, preserva o item."])
    Checkbox("desaturate", L["Dessaturar todos à venda"], L["Dessatura itens marcados para venda nas interfaces padrão da Blizzard."])

    Settings.RegisterAddOnCategory(category)
    BM.settingsCategory = category
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, loadedName)
    if loadedName ~= BM.name then return end
    events:UnregisterEvent("ADDON_LOADED")
    if C_Timer and C_Timer.After then C_Timer.After(0, RegisterSettingsCategory)
    else RegisterSettingsCategory() end
end)
