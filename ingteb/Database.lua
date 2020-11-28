local Constants = require("Constants")
local Helper = require("ingteb.Helper")
local Table = require("core.Table")
local Array = Table.Array
local Dictionary = Table.Dictionary
local ValueCacheContainer = require("core.ValueCacheContainer")
local Proxy = {
    Item = require("ingteb.Item"),
    Fluid = require("ingteb.Fluid"),
    Entity = require("ingteb.Entity"),
    Recipe = require("ingteb.Recipe"),
    MiningRecipe = require("ingteb.MiningRecipe"),
    Technology = require("ingteb.Technology"),
    Category = require("ingteb.Category"),
}
local StackOfGoods = require("ingteb.StackOfGoods")

local Database = ValueCacheContainer:new{}
Database.object_name = "Database"

function Database:new()
    if self.Proxies then return self end
    self.Proxies = {}
    self.RecipesForItems = {}
    self.RecipesForCategory = {}
    self.WorkersForCategory = {}
    self.EnabledTechnologiesForTechnology = {}

    for _, prototype in pairs(game.recipe_prototypes) do self:ScanRecipe(prototype) end
    for _, prototype in pairs(game.entity_prototypes) do self:ScanEntity(prototype) end
    for _, prototype in pairs(game.technology_prototypes) do self:ScanTechnology(prototype) end

    return self
end

function Database:GetProxy(className, name, prototype)
    self:OnLoad()
    local data = self.Proxies[className]
    if not data then
        data = Dictionary:new{}
        self.Proxies[className] = data
    end

    local key = name or prototype.name

    local result = data[key]
    if not result then
        result = Proxy[className]:new(name, prototype, self):SealUp()
        data[key] = result
    end

    return result
end

function Database:GetFluid(name, prototype) return self:GetProxy("Fluid", name, prototype) end
function Database:GetItem(name, prototype) return self:GetProxy("Item", name, prototype) end
function Database:GetEntity(name, prototype) return self:GetProxy("Entity", name, prototype) end
function Database:GetCategory(name, prototype) return self:GetProxy("Category", name, prototype) end
function Database:GetRecipe(name, prototype) return self:GetProxy("Recipe", name, prototype) end
function Database:GetMiningRecipe(name, prototype)
    return self:GetProxy("MiningRecipe", name, prototype)
end
function Database:GetTechnology(name, prototype) return self:GetProxy("Technology", name, prototype) end

function Database:AddWorkerForCategory(domain, category, prototype)
    self:GetCategory(domain .. "." .. category).Workers:Append(self:GetEntity(nil, prototype))
end

local function EnsureKey(data, key, value)
    local result = data[key]
    if not result then
        result = value or {}
        data[key] = result
    end
    return result
end

local function EnsureRecipeCategory(result, side, name, category)
    local itemData = EnsureKey(result, name)
    local sideData = EnsureKey(itemData, side, Dictionary:new())
    local categoryData = EnsureKey(sideData, "crafting." .. category, Array:new())
    return categoryData
end

function Database:ScanEntity(prototype)
    for category, _ in pairs(prototype.crafting_categories or {}) do
        self:AddWorkerForCategory("crafting", category, prototype)
    end
    for category, _ in pairs(prototype.resource_categories or {}) do
        if prototype.mineable_properties.required_fluid then
            self:AddWorkerForCategory("fluid-mining", category, prototype)

        else
            self:AddWorkerForCategory("mining", category, prototype)
        end
    end

    if prototype.mineable_properties --
    and prototype.mineable_properties.minable --
    and prototype.mineable_properties.products --
    and not prototype.items_to_place_this --
    then self:GetMiningRecipe(nil, prototype) end
end

function Database:ScanTechnology(prototype)
    for key, value in pairs(prototype.effects or {}) do
        if value.type == "unlock-recipe" then
            self:GetRecipe(value.recipe).TechnologyPrototypes:Append(prototype)
        end
    end
    for key, value in pairs(prototype.prerequisites or {}) do
        EnsureKey(self.EnabledTechnologiesForTechnology, key, Array:new()):Append(prototype)
    end

end

function Database:ScanRecipe(prototype)

    if prototype.hidden then return end

    for _, itemSet in pairs(prototype.ingredients) do
        EnsureRecipeCategory(self.RecipesForItems, "UsedBy", itemSet.name, prototype.category) --
        :Append(prototype.name)
    end

    for _, itemSet in pairs(prototype.products) do
        EnsureRecipeCategory(self.RecipesForItems, "CreatedBy", itemSet.name, prototype.category) --
        :Append(prototype.name)
    end

    EnsureKey(self.RecipesForCategory, "crafting." .. prototype.category, Array:new()):Append(
        prototype.name
    )

end

function Database:GetStackOfGoods(target)
    local amounts = {
        value = target.amount,
        probability = target.probability,
        min = target.amount_min,
        max = target.amount_max,
    }
    local goods --
    = target.type == "item" and self:GetItem(target.name) --
    or target.type == "fluid" and self:GetFluid(target.name) --
    if goods then return StackOfGoods:new(goods, amounts, self) end
end

function Database:AddBonus(target, technology)
    local result = self.Bonusses[target.type]
    if not result then
        result = Bonus(target.type, self)
        self.Bonusses[target.type] = result
    end
    result.CreatedBy:Append{Technology = technology, Modifier = target.modifier}

    return BonusSet(result, target.modifier, self)
end

function Database:OnLoad() self = self:new() end

function Database:Get(target)
    assert(target.type)
    assert(target.name)

    if target.type == "item" then return self:GetItem(target.name) end
    -- assert()
end

function Database:RefreshTechnology(target) self.Proxies.Technology[target.name]:Refresh() end

return Database
