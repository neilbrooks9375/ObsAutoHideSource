obs           = obslua
source_name   = ""
total_ms      = 0
hold          = 0
settings_     = nil

function disable_source()
    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
        for i, scn in ipairs(scenes) do
            local scene = obs.obs_scene_from_source(scn)
            local sceneitem = obs.obs_scene_find_source_recursive(scene, source_name)
            if sceneitem ~= nil then
                obs.obs_sceneitem_set_visible(sceneitem, false)
                break
            end
        end
        obs.bfree(scn)
        obs.source_list_release(scenes)
    end

	obs.timer_remove(disable_source)
end

function start_timer()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
        obs.obs_source_set_enabled(source, true)
        obs.timer_add(disable_source, total_ms)
	end

	obs.obs_source_release(source)

	obs.timer_remove(start_timer)
end

function activate(activating)
	obs.timer_remove(disable_source)

	if activating then
		local source = obs.obs_get_source_by_name(source_name)

		if source == nil then
			return
		end

		obs.obs_source_release(source)

        start_timer()
	end
end

function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
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

	obs.obs_properties_add_int(props, "duration_ms", "Duration (ms)", 1, 3600000, 1)

	return props
end

function script_description()
	return "Sets a source to hide at the end of a timer. The timer starts every time the source is made visible."
end

function script_update(settings)
	total_ms = obs.obs_data_get_int(settings, "duration_ms")
	source_name = obs.obs_data_get_string(settings, "source")

	activate(true)
end

function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "duration_ms", 10000)
end

function script_load(settings)
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_show", source_activated)
	obs.signal_handler_connect(sh, "source_hide", source_deactivated)

	settings_ = settings
end

function script_unload()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, true)
	end

	obs.obs_source_release(source)
end
