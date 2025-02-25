local icons = {
    ["pollution"] = { type = "entity", name = "biter-spawner" },
    ["warning"]   = { type = "virtual", name = "warning" },
    ["danger"]    = { type = "virtual", name = "danger" },
}
local sounds = {
    ["alert"] = { path = "utility/alert_destroyed" }
}

function init_mod(event)
    storage.spawners = {}
    for _, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = "unit-spawner" } }) or {} do
        table.insert(storage.spawners, entity.name)
    end
end

script.on_init(init_mod)
script.on_configuration_changed(init_mod)

script.on_event(defines.events.on_unit_group_created, function(event)
    local group = event.group
    -- Check if the group is valid and belongs to the enemy force
    if group and group.valid and group.force.name == "enemy" then
        local surface  = group.surface
        local position = group.position
        local pin      = surface.create_entity({
            name = "pin",
            position = position,
            force = "neutral"
        })

        -- Alert players
        if pin and pin.valid then
            -- Notify players on the same surface
            for _, player in pairs(game.connected_players) do
                if player.valid and player.surface == surface and player.mod_settings["enemy-alert-gathering"].value and player.is_alert_enabled(defines.alert_type.custom) then
                    -- Create the custom alert with the dummy entity indicating the position of the enemy group
                    player.add_custom_alert(pin, icons["warning"], { "enemy-alert.unit-group-gather" }, true)
                end
            end

            -- Destroy pin entity
            pin.destroy()
        end
    end
end)

script.on_event(defines.events.on_unit_group_finished_gathering, function(event)
    local group = event.group
    -- Check if the group is valid and belongs to the enemy force
    if group and group.valid and group.force.name == "enemy" then
        -- Get the group's command
        local command = group.command

        if command then
            local surface = group.surface
            local pin     = surface.create_entity({
                name = "pin",
                position = command.destination,
                force = "neutral"
            })

            -- Alert players
            if pin and pin.valid then
                -- Notify players on the same surface
                for _, player in pairs(game.connected_players) do
                    if player.valid and player.surface == surface and player.is_alert_enabled(defines.alert_type.custom) then
                        -- Create the custom alert with the dummy entity indicating the position of the enemy group
                        if command.type == defines.command.build_base and player.mod_settings["enemy-alert-expand"].value then
                            player.add_custom_alert(pin, icons["warning"], { "enemy-alert.unit-group-expand", #group.members }, true)
                        elseif command.type == defines.command.attack_area and player.mod_settings["enemy-alert-attack"].value then
                            player.add_custom_alert(pin, icons["danger"], { "enemy-alert.unit-group-attack", #group.members }, true)

                            if player.mod_settings["enemy-alert-notification-sound"].value then
                                player.play_sound(sounds["alert"])
                            end
                        end
                    end
                end

                -- Destroy pin entity
                pin.destroy()
            end
        end
    end
end)

script.on_event(defines.events.on_build_base_arrived, function(event)
    local group = event.group
    -- Check if the group is valid and belongs to the enemy force
    if group and group.valid and group.force.name == "enemy" then
        -- Get the group's command
        local command = group.command

        if command and command.type == defines.command.build_base then
            local surface  = group.surface
            local position = group.position
            local pin      = surface.create_entity({
                name = "pin",
                position = position,
                force = "neutral"
            })

            -- Alert players
            if pin and pin.valid then
                -- Notify players on the same surface
                for _, player in pairs(game.connected_players) do
                    if player.valid and player.surface == surface and player.mod_settings["enemy-alert-expand-arrive"].value and player.is_alert_enabled(defines.alert_type.custom) then
                        -- Create the custom alert with the dummy entity indicating the position of the enemy group
                        player.add_custom_alert(pin, icons["warning"], { "enemy-alert.unit-group-expand-arrive" }, true)
                    end
                end

                -- Destroy pin entity
                pin.destroy()
            end
        end
    end
end)

script.on_nth_tick(300, function(_)
    for _, surface in pairs(game.surfaces) do
        if surface and surface.valid then
            local pollution_count = 0

            for _, name in pairs(storage.spawners) do
                local count = game.get_pollution_statistics(surface).get_flow_count({
                    name = name,
                    category = "output",
                    precision_index = defines.flow_precision_index.five_seconds,
                    count = true,
                })
                pollution_count = pollution_count + math.floor(count + 0.5)
            end

            if pollution_count > 0 then
                -- Notify players on the same surface of the event and with custom alerts enabled
                for _, player in pairs(game.connected_players) do
                    if player.valid and player.surface == surface and player.mod_settings["enemy-alert-pollution"].value and player.is_alert_enabled(defines.alert_type.custom) then
                        local icon = icons["pollution"]
                        local entity = player.character

                        if not entity then
                            local entities = surface.find_entities_filtered { position = player.position }
                            if #entities > 0 then
                                entity = entities[1]
                            else
                                entity = surface.create_entity({
                                    name = "pin",
                                    position = player.position,
                                    force = "neutral",
                                })
                            end
                        end

                        if entity and entity.valid then
                            -- Do not spam the player with the same alert
                            player.remove_alert({
                                surface = surface,
                                type = defines.alert_type.custom,
                                icon = icon,
                            })

                            player.add_custom_alert(entity, icon, { "enemy-alert.spawners-consuming-pollution", pollution_count }, false)

                            if entity.name == "pin" then
                                entity.destroy()
                            end
                        end
                    end
                end
            end
        end
    end
end)

--- @param event EventData.CustomInputEvent
script.on_event("enemy-alert-pollution-toggle", function(event)
    local player = game.get_player(event.player_index)

    if player and player.valid and player.connected then
        local status                                 = player.mod_settings["enemy-alert-pollution"].value
        local enabled                                = { "enemy-alert.spawners-consuming-pollution-toggle-enabled" }
        local disabled                               = { "enemy-alert.spawners-consuming-pollution-toggle-disabled" }

        player.mod_settings["enemy-alert-pollution"] = {
            value = not status,
        }
        player.create_local_flying_text {
            text = { "enemy-alert.spawners-consuming-pollution-toggle", not status and enabled or disabled },
            position = player.position,
            color = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 },
        }
        if status then
            player.remove_alert({
                surface = player.surface,
                type = defines.alert_type.custom,
                icon = icons["pollution"],
            })
        end
    end
end)
