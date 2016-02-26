DEBUG = true

function debug_message(message)
  if DEBUG
    print(message)
  end
end

if DEBUG
  print("Waiting one second on timer 0")
  tmr.alarm(0, 1000, tmr.ALARM_SINGLE, 
    function() 
      dofile("main.lua")
      end)
else
  dofile("main.lua")
end
