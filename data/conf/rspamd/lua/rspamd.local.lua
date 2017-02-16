rspamd_config.MAILCOW_AUTH = {
	callback = function(task)
		local uname = task:get_user()
		if uname then
			return 1
		end
	end
}

rspamd_config.MAILCOW_MOO = function (task)
	return true
end

local modify_subject_map = rspamd_config:add_map({
  url = 'http://172.22.1.251:8081/tags.php',
  type = 'map',
  description = 'Map of users to use subject tags for'
})

local auth_domain_map = rspamd_config:add_map({
  url = 'http://172.22.1.251:8081/authoritative.php',
  type = 'map',
  description = 'Map of domains we are authoritative for'
})

rspamd_config.ADD_DELIMITER_TAG = {
  callback = function(task)
    local util = require("rspamd_util")
    local rspamd_logger = require "rspamd_logger"

    local user_env_tagged = task:get_recipients(1)[1]['user']
    local user_to_tagged = task:get_recipients(2)[1]['user']

    local domain = task:get_recipients(1)[1]['domain']

    local user_env, tag_env = user_env_tagged:match("([^+]+)+(.*)")
    local user_to, tag_to = user_to_tagged:match("([^+]+)+(.*)")

    local authdomain = auth_domain_map:get_key(domain)

    if tag_env then
      tag = tag_env
      user = user_env
    elseif tag_to then
      tag = tag_to
      user = user_env
    end

    if tag and authdomain then
      rspamd_logger.infox("Domain %s is part of mailcow, start reading tag settings", domain)
      local user_untagged = user .. '@' .. domain
      rspamd_logger.infox("Querying tag settings for user %1", user_untagged)
      if modify_subject_map:get_key(user_untagged) then
        rspamd_logger.infox("User wants subject modified for tagged mail")
        local sbj = task:get_header('Subject')
        if tag then
          rspamd_logger.infox("Found tag %1, will modify subject header", tag)
          new_sbj = '=?UTF-8?B?' .. tostring(util.encode_base64('[' .. tag .. '] ' .. sbj)) .. '?='
          task:set_rmilter_reply({
            remove_headers = {['Subject'] = 1},
            add_headers = {['Subject'] = new_sbj}
          })
        end
      else
        rspamd_logger.infox("Add X-Moo-Tag header")
        task:set_rmilter_reply({
          add_headers = {['X-Moo-Tag'] = 'YES'}
        })
      end
    else
      rspamd_logger.infox("Skip delimiter handling for untagged message or authenticated user")
    end
    return false
  end
}
