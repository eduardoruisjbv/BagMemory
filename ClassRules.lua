local _, BM = ...
local armor={WARRIOR=4,PALADIN=4,DEATHKNIGHT=4,HUNTER=3,SHAMAN=3,EVOKER=3,
    ROGUE=2,DRUID=2,MONK=2,DEMONHUNTER=2,MAGE=1,PRIEST=1,WARLOCK=1}
local armorSlots={INVTYPE_HEAD=true,INVTYPE_SHOULDER=true,INVTYPE_CHEST=true,INVTYPE_ROBE=true,
    INVTYPE_WAIST=true,INVTYPE_LEGS=true,INVTYPE_FEET=true,INVTYPE_WRIST=true,INVTYPE_HAND=true}
local weaponClasses={WARRIOR={[0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[10]=true,[15]=true},
    PALADIN={[0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true},
    DEATHKNIGHT={[0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true},
    HUNTER={[0]=true,[1]=true,[2]=true,[3]=true,[6]=true,[7]=true,[8]=true,[10]=true,[15]=true,[18]=true},
    SHAMAN={[0]=true,[1]=true,[4]=true,[5]=true,[10]=true,[13]=true,[15]=true},
    ROGUE={[0]=true,[4]=true,[7]=true,[13]=true,[15]=true},
    DRUID={[4]=true,[5]=true,[6]=true,[10]=true,[13]=true,[15]=true},
    MONK={[0]=true,[4]=true,[6]=true,[7]=true,[10]=true,[13]=true},
    DEMONHUNTER={[0]=true,[7]=true,[9]=true,[13]=true},
    MAGE={[7]=true,[10]=true,[15]=true,[19]=true},PRIEST={[4]=true,[10]=true,[15]=true,[19]=true},
    WARLOCK={[7]=true,[10]=true,[15]=true,[19]=true},EVOKER={[0]=true,[4]=true,[7]=true,[10]=true,[13]=true,[15]=true}}
-- Class-wide suitability for retention, independently of the current spec.
-- A different armor type is not a useful alternative for this character.
function BM:GearClassSuitable(item)
    if not item.gear then return nil end
    local class=self.playerClass
    if not class then local _,token=self:Call(UnitClass,"player");class=token end
    if not armor[class] then return nil end
    if item.class==4 and armorSlots[item.equipLoc] and item.subclass~=armor[class] then return false end
    if item.equipLoc=="INVTYPE_SHIELD" and class~="WARRIOR" and class~="PALADIN" and class~="SHAMAN" then return false end
    if item.class==2 and not (weaponClasses[class] and weaponClasses[class][item.subclass]) then return false end
    local allowed={WARRIOR={str=true},DEATHKNIGHT={str=true},PALADIN={str=true,int=true},
        HUNTER={agi=true},SHAMAN={agi=true,int=true},ROGUE={agi=true},DRUID={agi=true,int=true},
        MONK={agi=true,int=true},DEMONHUNTER={agi=true},MAGE={int=true},PRIEST={int=true},
        WARLOCK={int=true},EVOKER={int=true}}
    local groups={ITEM_MOD_STRENGTH_SHORT={"str"},ITEM_MOD_AGILITY_SHORT={"agi"},ITEM_MOD_INTELLECT_SHORT={"int"},
        ITEM_MOD_AGI_STR_INT_SHORT={"agi","str","int"},ITEM_MOD_AGI_STR_SHORT={"agi","str"},
        ITEM_MOD_AGI_INT_SHORT={"agi","int"},ITEM_MOD_STR_INT_SHORT={"str","int"}}
    local stats=item.stats or self:CachedItemCall(C_Item.GetItemStats,item.link)
    if type(stats)~="table" then return nil end
    local hasPrimary,matches=false,false
    for stat,attributes in pairs(groups) do
        local value=stats[stat]
        if issecretvalue and issecretvalue(value) then return nil end
        if type(value)=="number" and value>0 then
            hasPrimary=true
            for _,attribute in ipairs(attributes) do if allowed[class][attribute] then matches=true end end
        end
    end
    if hasPrimary and not matches then return false end
    return true
end

