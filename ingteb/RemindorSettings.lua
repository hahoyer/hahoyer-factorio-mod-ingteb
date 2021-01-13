local Constants = require("Constants")
local Helper = require("ingteb.Helper")
local Table = require("core.Table")
local Array = Table.Array
local Dictionary = Table.Dictionary

local Class = {}

local function GetGui(self)
    return {
        type = "flow",
        direction = "vertical",
        children = {
            {
                type = "flow",
                direction = "horizontal",
                children = {
                    {
                        type = "checkbox",
                        caption = "default",
                        state = self.Settings.AutoResearch == nil,
                        actions = {
                            on_checked_state_changed = {
                                module = "Remindor",
                                target = self.class.name,
                                action = "UpdateOverride",
                                control = "AutoResearch",
                                key = self.CommonKey,
                            },
                        },
                    },
                    {
                        type = "checkbox",
                        caption = "AutoResearch",
                        state = self.AutoResearch,
                        ignored_by_interaction = self.Settings.AutoResearch == nil,
                        actions = {
                            on_checked_state_changed = {
                                module = "Remindor",
                                target= self.class.name,
                                action = "Update",
                                control = "AutoResearch",
                                key = self.CommonKey,
                            },
                        },
                    },
                },
            },
            {
                type = "flow",
                direction = "horizontal",
                children = {
                    {
                        type = "checkbox",
                        caption = "default",
                        state = self.Settings.AutoCrafting == nil,
                        actions = {
                            on_checked_state_changed = {
                                module = "Remindor",
                                target= self.class.name,
                                action = "UpdateOverride",
                                control = "AutoCrafting",
                                key = self.CommonKey,
                            },
                        },
                    },
                    {
                        type = "drop-down",
                        items = {
                            "no auto-crafting",
                            "craft when 1 is possible",
                            "craft when 5 are possible",
                            "craft when requested are possible",
                        },
                        selected_index = self.AutoCrafting,
                        caption = "AutoCrafting",
                        ignored_by_interaction = self.Settings.AutoCrafting == nil,
                        actions = {
                            on_selection_state_changed = {
                                module = "Remindor",
                                target= self.class.name,
                                action = "Update",
                                control = "AutoCrafting",
                                key = self.CommonKey,
                            },
                        },
                    },
                },
            },
            {
                type = "flow",
                direction = "horizontal",
                children = {
                    {
                        type = "checkbox",
                        caption = "default",
                        state = self.Settings.RemoveTaskWhenFullfilled == nil,
                        actions = {
                            on_checked_state_changed = {
                                module = "Remindor",
                                target= self.class.name,
                                action = "UpdateOverride",
                                control = "RemoveTaskWhenFullfilled",
                                key = self.CommonKey,
                            },
                        },
                    },
                    {
                        type = "checkbox",
                        caption = "Remove task when fullfiled",
                        state = self.RemoveTaskWhenFullfilled,
                        ignored_by_interaction = self.Settings.RemoveTaskWhenFullfilled == nil,
                        actions = {
                            on_checked_state_changed = {
                                module = "Remindor",
                                target= self.class.name,
                                action = "Update",
                                control = "RemoveTaskWhenFullfilled",
                                key = self.CommonKey,
                            },
                        },
                    },
                },
            },
        },
    }
end

function Class.Open(remindor, self)
    if not self.Global.Location.RemindorSettings then
        self.Global.Location.RemindorSettings = {x = 200, y = 100}
    end
    local result = Helper.CreatePopupFrameWithContent(
        remindor, GetGui(self), {"ingteb-utility.reminder-tasks-settings"}, {subModule = "Settings"}
    )
    return result.Main
end

return Class
