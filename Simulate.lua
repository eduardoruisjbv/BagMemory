local _, BM = ...
local L=BM.L

local LIST_LIMIT=40

-- Read-only dry run: classifies the bags exactly like a merchant visit would,
-- but never sells, moves or modifies anything.
function BM:Simulate(verbose)
    self:Scan()
    local sell,others,reasons={}, {}, {}
    local total,value=0,0
    for _,item in ipairs(self.items) do
        if item.storage=="bag" then
            total=total+1
            if item.action=="sell" then
                sell[#sell+1]=item
                value=value+(item.sellPrice or 0)*(item.count or 1)
            else
                others[#others+1]=item
                local key=item.action.."|"..(item.reason or "?")
                reasons[key]=(reasons[key] or 0)+1
            end
        end
    end
    table.sort(sell,function(a,b) return (a.sellPrice or 0)*(a.count or 1)>(b.sellPrice or 0)*(b.count or 1) end)

    self:Print(string.format(L["Simulação (nada será vendido): %d pilhas na mochila · %d seriam vendidas · %s"],
        total,#sell,self:Money(value)))
    for i=1,math.min(#sell,LIST_LIMIT) do
        local item=sell[i]
        self:Print(string.format(L["  VENDER %s x%d: %s"],item.link or item.name or "?",item.count or 1,item.reason or "?"))
    end
    if #sell>LIST_LIMIT then self:Print(string.format(L["  … e mais %d pilhas a vender."],#sell-LIST_LIMIT)) end

    local grouped={}
    for key,count in pairs(reasons) do
        local action,reason=key:match("^(.-)|(.*)$")
        grouped[#grouped+1]={action=action,reason=reason,count=count}
    end
    table.sort(grouped,function(a,b) return a.count>b.count or a.count==b.count and a.reason<b.reason end)
    self:Print(L["Não vendidas, por motivo:"])
    for i=1,math.min(#grouped,12) do
        local g=grouped[i]
        self:Print(string.format("  %d × [%s] %s",g.count,g.action,g.reason))
    end
    if verbose then
        for _,item in ipairs(others) do
            self:Print(string.format("  %s [%s] %s",item.link or item.name or "?",item.action,item.reason or "?"))
        end
    else
        self:Print(L["Use /bm simular tudo para listar cada item não vendido."])
    end
end
