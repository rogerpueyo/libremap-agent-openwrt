--[[

Copyright 2015 Nicolás Echániz <nicoechaniz@altermundi.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

]]--

local json = require "luci.json"

function concat_tables(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

local function read_file(file_path)
    local f = assert(io.open(file_path, "r"))
    local c = f:read "*a"
    f:close()
    return c
end

local function clean_aliases(doc)
   if doc.aliases ~= nil then
      for i, alias in ipairs(doc.aliases) do
         if alias.type == "bmx7" then
            table.remove(doc.aliases, i)
         end
      end
   end
end

local function read_bmx7links()
    local bmx7links = {}
    local links_data = json.decode(read_file("/var/run/bmx7/json/links")).links
    local interfaces_data = json.decode(read_file("/var/run/bmx7/json/interfaces")).interfaces
    local llocalIps = {}

    for _, interface_data in pairs(interfaces_data) do
        if interface_data.state ~= "DOWN" then
            local llIp = string.sub(interface_data.llocalIp, 0, -4)
            table.insert(llocalIps, llIp)
        end
    end

    for _, link_data in pairs(links_data) do
        local remote_ip = link_data.llocalIp
        for _, interface_data in pairs(interfaces_data) do
            if interface_data.devName == link_data.viaDev then
                local_ip = string.sub(interface_data.llocalIp, 0, -4)
            end
        end
        local link = {
            type = "bmx7",
            alias_local = local_ip,
            alias_remote = remote_ip,
            quality = link_data.rxRate/100,
            attributes = {
                name = link_data.name,
                rxRate = link_data.rxRate,
                viaDev = link_data.viaDev,
            }
        }
        table.insert(bmx7links, link)
    end
    return llocalIps, bmx7links
end

function insert(doc)
   local llocalIps, bmx7links
   llocalIps, bmx7links = read_bmx7links()

-- clean the existing bmx7 aliases from the document
   clean_aliases(doc)
   local aliases = {}

   for _, llocalIp in ipairs(llocalIps) do
      table.insert(aliases, {type = "bmx7", alias = llocalIp })
   end

-- if aliases is not empty, insert aliases and bmx7links data in the doc
   if next(aliases) ~= nil then
       if doc["links"] ~= nil then
           concat_tables(doc.links, bmx7links)
       else
           doc.links = bmx7links
       end
       if doc["aliases"] ~= nil then
           concat_tables(doc.aliases, aliases)
       else
           doc.aliases = aliases
       end
   end
end

return {
    insert = insert
}
