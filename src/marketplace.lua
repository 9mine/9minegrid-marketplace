-- function used to check if requested service already available 
-- or it is in process of creation. If check fails, than next check
-- will be made in 5 seconds. If service is present HUD in right bottom
-- corner will show information and than in 20 seconds will be removed 
function check_service_availability(conn, player_name, name, helm_hud_id)
    local result = np_prot.file_read(conn.conn, "index")
    if result:find(name:gsub("^[0-9]+", "n").. "-svc", 1, true) then
        local res = name:gsub("^[0-9]+", "n") .. "-svc"
        res = res:gsub("%-", "%%%-")
        res = result:match("tcp%!" .. res .. "%![0-9]+")
        minetest.chat_send_player(player_name,
                                  "Resource " .. minetest.formspec_escape(res)  .. " found in registry")
        local player = minetest.get_player_by_name(player_name)
        player:hud_change(helm_hud_id, "text", name .. " installed")
        minetest.after(2, function() 
            minetest.show_formspec(player_name, "core:credentials",
            table.concat({"formspec_version[4]", "size[8,6,false]",
            "field[0,0;0,0;service_addr;;", minetest.formspec_escape(res) , "]",
            "hypertext[0, 0.3; 8, 1;; <bigger><center>", name, "<center><bigger>]",
            "field[0.5, 1.5; 7, 0.7;provider_token;Provider token;]",
            "field[0.5, 2.6; 7, 0.7;cloud_id;Cloud ID;]",
            "field[0.5, 3.7; 7, 0.7;folder_id;Folder ID;]",
            "button[5,4.8;2.5,0.7;send;send]",    }, ""))
        end)
        minetest.after(20, function() player:hud_remove(helm_hud_id) end)
        return
    end
    minetest.chat_send_player(player_name,
                              "Resource " .. name .. " not found in registry")
    minetest.after(5, check_service_availability, conn, player_name, name,
                   helm_hud_id)
end

-- function for handling player interaction with forms
-- shown after punching 'search' entity
local marketplace = function(player, formname, fields)
    if formname == "core:marketplace" then
        -- if esc key pressed then close form
        if fields.quit == "true" then return end
        local player_name = player:get_player_name()
        local repo_url = fields.url
        -- if pressed button 'install'
        if fields.install then
            minetest.show_formspec(player_name, "core:marketplace", "")
            local player_graph = graphs:get_player_graph(player_name)
            -- path to file in which data will be written after 'install' press
            -- by default, file 'install' if the same directory 
            local install_path = fields.platform_path == "/" and
                                     fields.platform.path .. "install" or
                                     fields.platform_path .. "/install"
            local conn = player_graph:get_platform(
                             common.get_platform_string(player)):get_conn()
            local result, response = pcall(np_prot.file_write, conn,
                                           install_path, repo_url)

            -- notify player about writing to file outcome
            minetest.chat_send_player(player_name, result and
                                          "File successfully saved" or
                                          "Editing file failed: " .. response)
            local registry_addr = os.getenv("REGISTRY_ADDR") ~= "" and
                                      os.getenv("REGISTRY_ADDR") or
                                      core_conf:get("REGISTRY_ADDR")
            local conn = connections:get_connection(player_name, registry_addr,
                                                    true)
            local helm_hud_id = player:hud_add(
                                    {
                    hud_elem_type = "text",
                    position = {x = 1, y = 0.97},
                    offset = {
                        x = -(string.len("Installing some long string there") *
                            10) - 5
                    },
                    text = "Installing " .. fields.repo_name,
                    number = 0xFF0000,
                    size = {x = 2},
                    scale = {x = 100, y = 100}
                })

            minetest.after(5, check_service_availability, conn, player_name,
                           fields.repo_name, helm_hud_id)
            return
        end
        local repo = ""
        local repo_idx = ""
        local repo_name = fields.repo_name
        -- get events of user interaction with table in formspec
        local event = core.explode_table_event(fields["repos"])
        -- if some row in the form was selected 
        -- set values if new formspec to those
        if event.row ~= 0 then
            local repos_for_k8s = minetest.deserialize(fields.repos_for_k8s)
            -- lua table with contains selected repository information
            repo = repos_for_k8s[event.row]
            -- ID of the row selected
            repo_idx = event.row
            repo_url = repo.url
            repo_name = repo.name
        end
        -- send new formspec to player with updated values
        minetest.show_formspec(player_name, "core:marketplace", table.concat(
                                   {
                "formspec_version[4]", "size[15.5,9,false]",
                "field[0,0;0,0;repo_name;;" ..
                    minetest.formspec_escape(repo_name) .. "]",
                "field[0,0;0,0;platform_path;;" ..
                    minetest.formspec_escape(fields.platform_path) .. "]",
                "field[0,0;0,0;repos_list;;" ..
                    minetest.formspec_escape(fields.repos_list) .. "]",
                "field[0,0;0,0;url;;" .. minetest.formspec_escape(repo_url) ..
                    "]", "field[0,0;0,0;repos_for_k8s;;" ..
                    minetest.formspec_escape(fields.repos_for_k8s) .. "]",
                "hypertext[0, 0.2; 15.5, 1;;<bigger><center>9mine marketplace</center></bigger>]",
                "table[0.5, 1.2; 7, 7.3;repos;" .. fields.repos_list .. ";" ..
                    repo_idx .. "]",
                "image[8, 1.2; 7, 3.8;" .. repo.name .. ".png]",
                "hypertext[8, 5.2; 7, 2.5;;<big><justify>" ..
                    minetest.formspec_escape(repo.description) ..
                    "</center></justify>]",
                "hypertext[8, 7.8; 3.5, 1;;<big>Rating: " .. repo.stargazerCount ..
                    " stars</big>]", "button[12, 7.8; 3, 0.7;install;install]"
            }, ""))
    end
end
register.add_form_handler("core:marketplace", marketplace)
local player_name = player:get_player_name()
local player_graph = graphs:get_player_graph(player_name)
local directory_entry = player_graph:get_entry(entity.entry_string)
local conn = player_graph:get_platform(common.get_platform_string(player))
                 :get_conn()
-- file read will return json array of objects
-- objects represents reposities, which nave '9minegrid-marketplace' tag
-- with following fields:
-- "openGraphImageUrl", "description", "stargazerCount", "name", "url"                                                                   
local response, content = pcall(np_prot.file_read, conn, directory_entry.path)
if not response then
    minetest.chat_send_player(player_name, content)
    return
else
    local json = require("cjson")
    -- convert json object to lua tables
    local repos_for_k8s = json.decode(content)
    local repos = ""
    -- generate string with repos names separated with commas
    -- each value represents row in a table
    -- download icons for repos
    for index, repo in pairs(repos_for_k8s) do
        repos = repos == "" and repo.name or repos .. "," .. repo.name
        texture.download(repo.openGraphImageUrl, true, repo.name .. ".png",
                         "marketplace")
    end
    minetest.show_formspec(player_name, "core:marketplace", table.concat(
                               {
            "formspec_version[4]", "size[15.5,9,false]",
            "field[0,0;0,0;platform_path;;" ..
                minetest.formspec_escape(directory_entry.platform_path) .. "]",
            "field[0,0;0,0;repos_list;;" .. minetest.formspec_escape(repos) ..
                "]", "field[0,0;0,0;repos_for_k8s;;" ..
                minetest.formspec_escape(minetest.serialize(repos_for_k8s)) ..
                "]",
            "hypertext[0, 0.2; 15.5, 1;;<bigger><center>9mine marketplace</center></bigger>]",
            "table[0.5, 1.2; 7, 7.3;repos;" .. repos .. ";]",
            "image[8, 1.2; 7, 3.8;core_marketplace.png]",
            "hypertext[8, 5.2; 7, 3.3;;Welcome to 9mine marketplace. Please, choose one of available filesystems and press 'install'. This will deploy filesystem on a k8s cluster. New filesystem address will appear in the 9mine registry (use tool 'registry' to access 9mine registry). \n ! Please, note, that filesystem deployment could take up to 2 minutes. Until deployment is finished, fileystem will not appear in registry.]"
        }, ""))
    return
end
