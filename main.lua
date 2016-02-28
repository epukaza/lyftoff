print("starting main.lua")

local srv = nil
local button_pin = 6
local pwm_pin = 1
local pwm_timer = 1
local pwm_freq = 500
local pwm_max_bright = 1023
local config = nil -- sensitive data loaded at runtime

function debounce (func)
    local last = 0
    local delay = 200000

    return function (...)
        local now = tmr.now()
        if now - last < delay then return end

        last = now
        return func(...)
    end
end

function jsonify(payload)
  open_brace, close_brace = string.find(payload, '^{.*}')
  return cjson.decode(string.sub(payload, open_brace, close_brace))
end

function on_change()
  debug_message('on_change')
  pwm_fadeout()
  --[[
  Since one of the legs in our 3-legged OAUTH is a peg leg, 
  we opt to refresh on every request. ESPs can barely keep time anyway.
  ]]
  -- http.post(
  --   'https://api.lyft.com/oauth/token',
  --   'Content-Type: application/json\r\n'
  --   .. 'Authorization: Basic ' .. config.base64_auth .. '\r\n',
  --   '{"grant_type": "refresh_token", "refresh_token": "' .. config.refresh_token .. '"}\r\n\r\n',
  --   function(code, data)
  --     debug_message('token refresh status code: ' .. (code or 'nil'))
  --     debug_message('token refresh resp data: ' .. (data or 'nil'))

  --     json_data = jsonify(data)

      debug_message('Requesting ride')
      http.post(
        'https://api.lyft.com/v1/rides',
        'Authorization: Bearer ' .. 'SANDBOX-gAAAAABW0mvDUr9fc7Vgw6GF7Jv7ps5KRWw0sqd4jrg-p-tetlI5iL2ulbctnlV6y58B2mvOUrR7Huk13kQ2uhqrwV9vfK_BLTQ7vLynJSD0Y9Uw1UgpIyZeDV2q0RQ7Sxtf0-qTPgaXQyFLmUZDW-teuE6KTjv6srJ2naEMGe-QtAJnpLdrnw9ZDsB0RJwpK9Heq6Vbt3j4aXvXtacvprZ1S1oU8JIZ7IWbcoTVu4GkcvxFq6OFvRauUR1nTorQOk49h-bx_iKxd_pp2G7ZgyYLwFsPojpied_y17RLhGntMYQKH0yZvo0=' .. '\r\n'
        .. 'Content-Type: application/json\r\n',
        '{"ride_type" : "lyft", "origin" : {"lat" : 37.804427, "lng" : -122.429473 } }\r\n\r\n',
        function(code, data)
          debug_message('ride request status code: ' .. (code or 'nil'))
          debug_message('ride request resp data: ' .. (data or 'nil'))

          debug_message("Sending IFTTT notification")
          ip = wifi.sta.getip()
          http.post(
            'https://maker.ifttt.com/trigger/lyftoff/with/key/' .. config.ifttt_event_key,
            'Content-Type: application/json\r\n',
            '{"value1": "' .. ip .. '"}\r\n\r\n',
            function(code, data)
              debug_message('ifttt status code: ' .. (code or 'nil'))
              debug_message('ifttt resp data: ' .. (data or 'nil'))
              print("LYFT OFF!")
            end
          )
        end
      )
  --   end
  -- )
end

function start_server()
  debug_message('server start')
  debug_message(srv)

  if srv then
    srv = nil
  end
  srv = net.createServer(net.TCP, 30)
  srv:listen(80, connect)
  debug_message(srv)
end

function stop_server()
  debug_message('server stop')
  debug_message(srv)
  if srv then
    srv:close()
    srv = nil
  end
  debug_message(srv)
end

function connect(sock)
  sock:on('receive', function(sock, payload)
    if string.match(payload, 'fadeinplease') then
      pwm_fadein()
    end

    if string.match(payload, 'fadeoutplease') then
      pwm_fadeout()
    end
  end)

  sock:on('sent', function(sck)
    sck:close()
  end)
end

function on_start()
  debug_message('on_start')

  debug_message('on_start: reading config')
  file.open('config.json')
  config = cjson.decode(file.read())
  file.close()

  debug_message('on_start: connecting')
  wifi.sta.config(config.ssid, config.pwd)

  debug_message('on_start: starting server to receive pushes')
  start_server()

  debug_message('on_start: enable pwm')
  pwm.setup(pwm_pin, pwm_freq, 0)
  pwm.start(pwm_pin)
  pwm_fadein()
end

function pwm_fadein()
  local brightness = pwm.getduty(pwm_pin)

  if brightness >= pwm_max_bright then
    tmr.unregister(pwm_timer)
  else
    pwm.setduty(pwm_pin, brightness + 1)
    tmr.alarm(pwm_timer, 2, tmr.ALARM_SINGLE, pwm_fadein)
  end
end

function pwm_fadeout()
  local brightness = pwm.getduty(pwm_pin)

  if brightness <= 0 then
    tmr.unregister(pwm_timer)
  else
    pwm.setduty(pwm_pin, brightness - 3)
    tmr.alarm(pwm_timer, 2, tmr.ALARM_SINGLE, pwm_fadeout)
  end
end

on_start()
gpio.mode(button_pin, gpio.INT)
gpio.trig(button_pin, 'down', debounce(on_change))
