local gui = require("__flib__.gui-beta")
local Constants = require("Constants")
local Helper = require("ingteb.Helper")
local Table = require("core.Table")
local Array = Table.Array
local Dictionary = Table.Dictionary
local UI = require("core.UI")
local class = require("core.class")
local RequiredThings = require("ingteb.RequiredThings")
local Item = require("ingteb.Item")
local RemindorSettings = require "ingteb.RemindorSettings"

local Class = class:new(
    "Task", nil, {
        Global = {get = function(self) return self.Parent.Global end},
        Player = {get = function(self) return self.Parent.Player end},
        Database = {get = function(self) return self.Parent.Database end},
        LocalSettings = {get = function(self) return self.Settings end},
        DefaultSettings = {get = function(self) return self.Parent end},

        IsIrrelevantSettings = {
            get = function(self)
                return {
                    AutoResearch = not self.Recipe.Required.Technologies:Any(),
                    AutoCrafting = self.Worker.Name ~= "character",
                }
            end,
        },

        AutoResearch = {
            get = function(self)
                if not self.Recipe.Required.Technologies:Any() then return end
                if self.Settings.AutoResearch ~= nil then
                    return self.Settings.AutoResearch
                end
                return self.Parent.AutoResearch
            end,
        },
        AutoCrafting = {
            get = function(self)
                if self.Worker.Name ~= "character" then return end
                if self.Settings.AutoCrafting ~= nil then
                    return self.Settings.AutoCrafting
                end
                return self.Parent.AutoCrafting
            end,
        },
        RemoveTaskWhenFulfilled = {
            get = function(self)
                if self.Settings.RemoveTaskWhenFulfilled ~= nil then
                    return self.Settings.RemoveTaskWhenFulfilled
                end
                return self.Parent.RemoveTaskWhenFulfilled
            end,
        },
        IsRelevant = {
            get = function(self)
                return not self.RemoveTaskWhenFulfilled or not self.IsFulfilled
            end,
        },
        IsFulfilled = {
            get = function(self) return self.CountAvailable >= self.Target.Amounts.value end,
        },

        CountAvailable = {
            get = function(self)
                return self.Database:GetCountAvailable(self.Target.Goods)
            end,
        },

        RemainingAmount = {
            get = function(self) return self.Target.Amounts.value - self.CountAvailable end,
        },

        RemainingAmountForAutocrafting = {
            get = function(self)
                if self.Worker.Name ~= "character" then return 0 end
                return self.RemainingAmount
            end,
        },

        CurrentTarget = {
            get = function(self)
                local value = -self.RemainingAmount
                local result = self.Target.Goods:CreateStack(value ~= 0 and {value = value} or nil)
                result.GetCustomHelp = function(result)
                    return {{"", {"ingteb-utility.requested-amount"}, self.Target.Amounts.value}}
                end

                return result
            end,
        },

    }
)

function Class:GetSelection()
    return {
        Target = self.Target.Goods.CommonKey,
        Count = self.Target.Amounts.value,
        Worker = self.Worker.CommonKey,
        Recipe = self.Recipe.CommonKey,
        CommonKey = self.CommonKey,
        Settings = self.Settings,
    }
end

function Class:AddSelection(selection)
    dassert(selection.Target == self.Target.Goods.CommonKey)
    dassert(selection.Worker == self.Worker.CommonKey)
    dassert(selection.Recipe == self.Recipe.CommonKey)
    dassert(selection.CommonKey == self.CommonKey)

    local value --
    = (self.Target.Amounts and self.Target.Amounts.value or 0) --
    + (selection.Count or 0)
    self.Target.Amounts = value ~= 0 and {value = value} or nil
end

function Class:new(selection, parent)
    local self = self:adopt{Parent = parent, Settings = Dictionary:new(selection.Settings):Clone()}
    self.SettingsGui = RemindorSettings:new(self, {ButtonSize = 30})
    self.Target = self.Database:GetProxyFromCommonKey(selection.Target):CreateStack{
        value = selection.Count,
    }
    self.Worker = self.Database:GetProxyFromCommonKey(selection.Worker)
    self.Recipe = self.Database:GetProxyFromCommonKey(selection.Recipe)
    self.CommonKey = selection.CommonKey
    return self
end

function Class:CheckAutoResearch()
    if self.AutoResearch == "off" then return end
    if not self.Recipe.Required.Technologies:Any() then return end

    self.Database:BeginMulipleQueueResearch(self.Recipe.Technology, self.AutoResearch)
end

function Class:CheckAutoCrafting()
    if self.Worker.Name ~= "character" then return end
    if self.Recipe.class.name ~= "Recipe" then return end
    local player = game.players[self.Global.Index]
    if player.crafting_queue_size > 0 then return end

    local toDo = self.RemainingAmountForAutocrafting
    if toDo <= 0 then return end

    if self.AutoCrafting == "off" then
        return
    elseif self.AutoCrafting == "1" then
        toDo = math.min(toDo, 1)
    elseif self.AutoCrafting == "5" then
        toDo = math.min(toDo, 5)
    end

    local craftable = self.Recipe.CraftableCount
    if toDo > craftable then return end
    player.begin_crafting {count = toDo, recipe = self.Recipe.Name}
end

function Class:AutomaticActions()
    self:CheckAutoResearch()
    self:CheckAutoCrafting()
end

function Class:CreatePanel(frame, key, data, isTop, isBottom, required)
    Spritor:StartCollecting()
    local guiData = self:GetGui(key, data, isTop, isBottom, required)
    local result = gui.build(frame, {guiData})
    Spritor:RegisterDynamicTargets(result.DynamicElements)
end

local function GetDragTooltip(isTop, isBottom)
    if isTop and isBottom then return end
    return {
        "",
        not isTop and {
            "",
            UI.GetHelpTextForButtons({"ingteb-utility.move-task-to-top"}, "--S l"),
            "\n",
            UI.GetHelpTextForButtons({"ingteb-utility.move-task-up"}, "--- l"),
        } or "",
        not isTop and not isBottom and "\n" or "",
        not isBottom and {
            "",
            UI.GetHelpTextForButtons({"ingteb-utility.move-task-down"}, "--- r"),
            "\n",
            UI.GetHelpTextForButtons({"ingteb-utility.move-task-to-bottom"}, "--S r"),
        } or "",
    }
end

function Class:GetGui(key, data, isTop, isBottom, required)
    return {
        type = "frame",
        direction = "horizontal",
        name = key,
        style_mods = {left_padding = 0, right_padding = 2, top_padding = 1, bottom_padding = 1},
        children = {
            {
                type = "empty-widget",
                style = "flib_titlebar_drag_handle",
                ref = {"UpDownDragBar"},
                style_mods = {width = 15, height = 40},
                actions = {
                    on_click = {target = "Task", module = "Remindor", action = "Drag", key = key},
                },
                tooltip = GetDragTooltip(isTop, isBottom),
            },
            Spritor:GetSpriteButtonAndRegister(self.CurrentTarget),
            Spritor:GetSpriteButtonAndRegister(self.Worker),
            Spritor:GetSpriteButtonAndRegister(self.Recipe),
            {
                type = "frame",
                direction = "horizontal",
                children = {self.SettingsGui:GetGui(required.Settings)},
                style_mods = {padding = 1},
            },
            Spritor:GetLinePart(self:GetRequired(data), required.Things),
            {
                type = "sprite-button",
                sprite = "utility/close_white",
                style = "frame_action_button",
                style_mods = {size = 17},
                ref = {"Remindor", "Task", "CloseButton"},
                actions = {
                    on_click = {target = "Task", module = "Remindor", action = "Remove", key = key},
                },
                tooltip = {"gui.close"},
            },
        },
    }
end

function Class:CreateCloseButton(global, frame, functionData)
    local closeButton = frame.add {
        type = "sprite",
        sprite = "utility/close_black",
        tooltip = {"gui.close"},
    }
    global.Remindor.Links[closeButton.index] = functionData
end

function Class:EnsureInventory(goods, data)
    local key = goods.CommonKey
    if data[key] then return end
    if goods.class == Item then
        data[key] = self.Player.get_main_inventory().get_item_count(goods.Name)
    else
        data[key] = 0
    end
end

function Class:GetRequired(data)
    local target = RequiredThings:new(
        self.Recipe.Required.Technologies, --
        self.Recipe.Required.StackOfGoods --
        and self.Recipe.Required.StackOfGoods --
        :Select(
            function(stack, key)
                self:EnsureInventory(stack.Goods, data)
                local inventory = data[key]

                local countByRecipe --
                = self.Recipe.Output --
                :Where(function(stack) return stack.Goods == self.Target.Goods end) --
                :Top().Amounts.value

                local count = inventory --
                - self.RemainingAmountForAutocrafting * stack.Amounts.value / countByRecipe

                local value = math.min(count, 0)
                data[key] = math.max(count, 0)
                return stack.Goods:CreateStack(value ~= 0 and {value = value} or nil)
            end
        ) --
        or nil
    )

    local result = target:GetData()
    return result

end

function Class:ScanRelevantSettings(result, tag)
    if result[tag] then return end
    result[tag] = not self.SettingsGui.IsIrrelevant or not self.SettingsGui.IsIrrelevant[tag]
end

function Class:ScanRequired(required)
    local value = self.Recipe.Required:Count()
    if value > required.Things then required.Things = value end
    self:ScanRelevantSettings(required.Settings, "AutoResearch")
    self:ScanRelevantSettings(required.Settings, "AutoCrafting")
    self:ScanRelevantSettings(required.Settings, "RemoveTaskWhenFulfilled")
end

return Class
