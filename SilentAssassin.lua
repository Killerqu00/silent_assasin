-------------------------------------------------
--  Menu Logic
-------------------------------------------------
_G.SilentAssassin = _G.SilentAssassin or {}
SilentAssassin._path = ModPath
SilentAssassin._data_path = SavePath .. "silentassassin.txt"
-- num_pagers -> number of pagers allowed.
-- num_pagers_per_player -> maximum number of pagers a single
-- 	player may use
SilentAssassin.settings = {}

--Loads the options from blt
function SilentAssassin:Load()
    self.settings["num_pagers"] = 2
    self.settings["num_pagers_per_player"] = 2
    self.settings["enabled"] = true
    self.settings["stealth_kill_enabled"] = true

    local file = io.open(self._data_path, "r")
    if (file) then
        for k, v in pairs(json.decode(file:read("*all"))) do
            self.settings[k] = v
        end
    end
end

--Saves the options
function SilentAssassin:Save()
    local file = io.open(self._data_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

--Loads the data table for the menuing system.  Menus are
--ones based
function SilentAssassin:getCompleteTable()
    local tbl = {}
    for i, v in pairs(SilentAssassin.settings) do
        if i == "num_pagers" then
            tbl[i] = v + 1
        elseif  i == "num_pagers_per_player" then
            tbl[i] = v + 1
        else
            tbl[i] = v
        end
    end

    return tbl
end

--Sets number of pagers.  Called from the menu system.  Menus are all ones
--based
function setNumPagers(this, item)
    SilentAssassin.settings["num_pagers"] = item:value() - 1
end

function setNumPagersPerPlayer(this, item)
    SilentAssassin.settings["num_pagers_per_player"] = item:value() - 1
end

function setEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["enabled"] = value
end

function setStealthKillEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["stealth_kill_enabled"] = value
end

--Load locatization strings
Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_SilentAssassin", function(loc)
    loc:load_localization_file(SilentAssassin._path.."loc/en.txt")
end)

--Set up the menu
Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_SilentAssassin", function(menu_manager)
    MenuCallbackHandler.SilentAssassin_setNumPagers = setNumPagers
    MenuCallbackHandler.SilentAssassin_setNumPagersPerPlayer = setNumPagersPerPlayer
    MenuCallbackHandler.SilentAssassin_enabledToggle = setEnabled
    MenuCallbackHandler.SilentAssassin_killPagerEnabledToggle = setStealthKillEnabled

    MenuCallbackHandler.SilentAssassin_Close = function(this)
        SilentAssassin:Save()
    end

    SilentAssassin:Load()
    MenuHelper:LoadFromJsonFile(SilentAssassin._path.."options.txt", SilentAssassin, SilentAssassin:getCompleteTable())
end)

-- gets the number of pagers, triggering a load if necessary.  Called
-- by clients
function getNumPagers()
    if not SilentAssassin.settings["num_pagers"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers"]
end

function getNumPagersPerPlayer()
    if not SilentAssassin.settings["num_pagers_per_player"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers_per_player"]
end

function isSAEnabled()
    if not SilentAssassin.settings["enabled"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["enabled"]
end

function isStealthKillEnabled()
    if not SilentAssassin.settings["stealth_kill_enabled"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["stealth_kill_enabled"]
end

-------------------------------------------------
--  Handler for damaged received
-------------------------------------------------

if RequiredScript == "lib/units/enemies/cop/copbrain" then
    if not _CopBrain_clbk_damage then
        _CopBrain_clbk_damage = CopBrain._clbk_damage
    end

    function CopBrain:clbk_damage(my_unit, damage_info)
        if _CopBrain_clbk_damage then 
            --this seems to get called on damage but not on death
            --So if we take any non-fatal damage, the pager will go off
            --log ("non-fatal damage")
            self._cop_pager_ready = true
            _CopBrain_clbk_damage(self, my_unit, damage_info)
            --log ("made parent callback")
        end
    end

    if not _CopBrain_clbk_death then
        _CopBrain_clbk_death = CopBrain.clbk_death
    end
    function CopBrain:clbk_death(my_unit, damage_info)
        --log ("clbk_death")
        log ("SA enabled " .. tostring(isSAEnabled()))
        log ("SK enabled " .. tostring(isStealthKillEnabled()))
        if isSAEnabled() and isStealthKillEnabled() then
            local head
            if damage_info.col_ray then 
                --the idea was to require a headshot.  It turns out that col_ray is not
                --set when the client takes the shot so I can only do OHKs on clients.
                --I figure to make things fair it should be OHKs for everyone
                --head = self._unit:character_damage()._head_body_name and damage_info.col_ray.body and damage_info.col_ray.body:name() == self._unit:character_damage()._ids_head_body_name
                head = true
            else
                --OHK keeps the pager from going ff
                head = true
            end
            if not head then
                --log ("enabling pager")
                --not headshots will cause the pager to go off
                self._cop_pager_ready = true
            end
            --if self._cop_pager_ready then
                --log("_cop_pager_ready is true")
            --end

            --log(tostring(self._unit:movement():stance_name()))
            --if self._unit:movement():cool() then
                --log("unit is cool")
            --end

            --cool() doesn't work for the camera operator on First World Bank.  For
            --some reason he's in stance "cbt" (and therefore uncool) even if he's not
            --alerted.  I figure this is a bug in the map.
            --if not self._cop_pager_ready and self._unit:movement():cool() then
            if not self._cop_pager_ready and self._unit:movement():stance_name() ~= "hos" then
                --we're dead and the pager is not ready, so delete it
                --log ("pager disabled")
                self._unit:unit_data().has_alarm_pager = false
            end
        end
        _CopBrain_clbk_death(self, my_unit, damage_info)
    end
end


-------------------------------------------------
--  Setting number of pagers
-------------------------------------------------
if RequiredScript == "lib/units/enemies/cop/copbrain" then
    if not _CopBrain_on_alarm_pager_interaction then
        _CopBrain_on_alarm_pager_interaction = CopBrain.on_alarm_pager_interaction
    end

    --This is called when a player interacts with a pager.  Swap in the
    --correct table before actually running the pager interaction
    function CopBrain:on_alarm_pager_interaction(status, player)
        if isSAEnabled() then
            if status == "complete" then
                --This is where the pager really runs
                local bluffChance = {}
                local numPagers;
                numPagers = getNumPagers()

                --Track the number of pagers a player has answered in the player
                --object
                if not player:base().num_answered then
                    player:base().num_answered = 0
                end

                --log("NumAnswered" .. tostring(player:base().num_answered))

                --If this player can answer a pager, write up to
                --getNumPagersPerPlayer() 1's into the table, otherwise
                --write all 0's.  This way the real on_alarm_pager_interaction
                --will index into the table as normal
                player:base().num_answered = player:base().num_answered + 1
                local tableValue
                if player:base().num_answered <= getNumPagersPerPlayer() then
                    tableValue = 1
                else
                    tableValue = 0
                end
                for i = 0, ( numPagers - 1), 1 do
                    table.insert(bluffChance, tableValue)
                end
                table.insert(bluffChance, 0)

                tweak_data.player.alarm_pager["bluff_success_chance"] = bluffChance
                tweak_data.player.alarm_pager["bluff_success_chance_w_skill"] = bluffChance
            end
        end
        _CopBrain_on_alarm_pager_interaction(self, status, player)
    end
end

Hooks:Add("NetworkManagerOnPeerAdded", "NetworkManagerOnPeerAdded_SA", function(peer, peer_id)
	if Network:is_server() and isSAEnabled() then
        local skEnabled = isStealthKillEnabled()
        local numPagers = getNumPagers()
        local numPerPlayer = getNumPagersPerPlayer()

		DelayedCalls:Add("DelayedSAAnnounce" .. tostring(peer_id), 2, function()

			local message = "Host is running 'Silent Assassin'.  "
            if skEnabled then
                message = message .. "Kills on unalerted guards do not trigger pagers.  "
            end

            message = message .. "A maximum of " .. tostring(numPagers) .. " pagers are allowed, and each player may answer up to " .. tostring(numPerPlayer) .. " pagers."
			local peer2 = managers.network:session() and managers.network:session():peer(peer_id)
			if peer2 then
				peer2:send("send_chat_message", ChatManager.GAME, message)
			end
		end)
	end
end)
