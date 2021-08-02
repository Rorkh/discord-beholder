_G.TURBO_SSL = true

local gt67r4 = require("gt67r4")
local json = require("cjson")

local discord_token = "Bot <your_bot_token>"
local target_guild = "<your_guild_id>"

local client = gt67r4:Client(discord_token)
local channels, messages, guild = {}, {}, {}

print("Beholder started")

client:getGuild(function(guild_object) guild = guild_object end, target_guild)
print("Gathering information about " .. guild.name)
client:getGuildChannels(function(channels_list) channels = channels_list end, target_guild)

local ffi = require "ffi"
ffi.cdef "unsigned int sleep(unsigned int seconds);"
local C = ffi.C

for _, channel in ipairs(channels) do
	print("Gathering information about " .. channel.name .. " (" .. channel.id .. ") channel")	
	
	local last_message = channel.last_message_id

	while true do
		local messages_chunk = {}		

		client:getChannelMessages(function(messages_object)
			messages_chunk = messages_object
		end, channel.id, {limit = 100, before = last_message})
		
		if #messages_chunk == 0 then break end 
		for _, message in ipairs(messages_chunk) do messages[#messages + 1] = message end
		last_message = messages[#messages].id
				
		ffi.C.sleep(1)
	end
end

local authors_top = {}
local words_count = {}
local day_top = {}

local rmessages_stream = io.open("messages_raw.txt", "a+")
local messages_stream = io.open("messages.txt", "a+")

local authors_stream = io.open("authors.txt", "a+")
local words_stream = io.open("words.txt", "a+")
local day_stream = io.open("days.txt", "a+")

local function parse_json_date(json_date)
    local pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%-])(%d?%d?)%:?(%d?%d?)"
    local year, month, day, hour, minute, 
        seconds, offsetsign, offsethour, offsetmin = json_date:match(pattern)
    local timestamp = os.time{year = year, month = month, 
        day = day, hour = hour, min = minute, sec = seconds}
    local offset = 0
    if offsetsign ~= 'Z' then
      offset = tonumber(offsethour) * 60 + tonumber(offsetmin)
      if xoffset == "-" then offset = offset * -1 end
    end
    
    return timestamp + offset
end

for _, message in ipairs(messages) do
	local date = parse_json_date(message.timestamp)
	local day = os.date("%x", date)
	
	if message.content then
		for word in message.content:gmatch("%S+") do
			if not words_count[word] then words_count[word] = 0 end
			words_count[word] = words_count[word] + 1
		end
	end

	local author = message.author.username
	if not authors_top[author] then authors_top[author] = 0 end
	authors_top[author] = authors_top[author] + 1

	if not day_top[day] then day_top[day] = 0 end
	day_top[day] = day_top[day] + 1

	rmessages_stream:write(json.encode(message) .. "\n")
	messages_stream:write(author .. ": " .. message.content .. "\n")
end

for k, v in pairs(authors_top) do authors_stream:write(k .. ": " .. v .. "\n") end
for k, v in pairs(words_count) do words_stream:write(k .. ": " .. v .. "\n") end 
for k, v in pairs(day_top) do day_stream:write(k .. ": " .. v .. "\n") end

rmessages_stream:close()
messages_stream:close()

authors_stream:close()
words_stream:close()
day_stream:close()

print("Beholder finished")
