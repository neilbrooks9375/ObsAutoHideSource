obs           = obslua
source_names  = {}
total_ms      = 0
hold          = 0
settings_     = nil

function disable_source(sourceName)
    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
        for i, scn in ipairs(scenes) do
            local scene = obs.obs_scene_from_source(scn)
            local sceneitem = obs.obs_scene_find_source_recursive(scene, sourceName)
            if sceneitem ~= nil then
                obs.obs_sceneitem_set_visible(sceneitem, false)
                break
            end
        end
        obs.bfree(scn)
        obs.source_list_release(scenes)
    end

    obs.timer_remove(get_disable_source_function(sourceName))
end

disable_functions = {}
get_disable_source_function = function (sourceName)
    if not disable_functions[sourceName] then
        disable_functions[sourceName] = function ()
            disable_source(sourceName)
        end
    end
    return disable_functions[sourceName]
end

function start_timer(sourceName)
    obs.timer_remove(get_disable_source_function(sourceName))
    obs.timer_add(get_disable_source_function(sourceName), total_ms)
end

function activate(activating, sourceName)
    obs.timer_remove(get_disable_source_function(sourceName))

    if activating then
        local source = obs.obs_get_source_by_name(sourceName)

        if source == nil then
            return
        end

        obs.obs_source_release(source)

        start_timer(sourceName)
    end
end

function activate_signal(cd, activating)
    local source = obs.calldata_source(cd, "source")
    if source ~= nil then
        local name = obs.obs_source_get_name(source)
        if source_selected(name) then
            activate(activating, name)
        end
    end
end

function source_selected(src)
    local count = obs.obs_data_array_count(source_names)
    for i = 0, count do
        local item = obs.obs_data_array_item(source_names, i)
        local sourceName = obs.obs_data_get_string(item, "value")
        if src == sourceName then
            return true
        end
    end
    return false
end

function source_activated(cd)
    activate_signal(cd, true)
end

function source_deactivated(cd)
    activate_signal(cd, false)
end

function script_properties()
    local props = obs.obs_properties_create()

    local p = obs.obs_properties_add_list(props, "source", "Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(p, name, name)
        end
    end
    obs.source_list_release(sources)

    obs.obs_properties_add_editable_list(props, "sources", "Sources", obs.OBS_EDITABLE_LIST_TYPE_STRINGS, nil, nil)

    obs.obs_properties_add_int(props, "duration_ms", "Duration (ms)", 1, 3600000, 1)

    return props
end

function script_description()
    return "Sets a source to hide at the end of a timer. The timer starts every time the source is made visible."
end

function script_update(settings)
    total_ms = obs.obs_data_get_int(settings, "duration_ms")
    source_names = obs.obs_data_get_array(settings, "sources")

    --activate(true)
end

function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "duration_ms", 5000)
end

function script_load(settings)
    local sh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(sh, "source_show", source_activated)
    obs.signal_handler_connect(sh, "source_hide", source_deactivated)

    settings_ = settings
end
