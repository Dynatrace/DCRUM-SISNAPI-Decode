require 'amd'

-- Janusz Dabrowski, Dynatrace, 2015

function script_name()
        return "SISNAPI Simple Parser Decode"
end

-- set deb = 1 for detailed logging in rtm.log for diagnostic purposes
deb = 0

-- text to string
local function number(pstr, offset, size)
	local number = 0
	local max = size - 1
	for i = 0, max 
		do
			number = number * 256
			number = (number + pstr:byte(offset + i))
		end 
  return number
end


-- convert utf16 to utf8, ignors non-ASCII chars
local function utf(parr,max)
 
    local out_string = ""
    for i = 1, max   
		do
			if i % 2 == 0 
			then 
				if string.byte(parr:sub(i,i)) > 0x1F 
				then 
					out_string = out_string .. (parr:sub(i,i))
				else
					out_string = out_string .. " "
				end
			end
		end 
	return out_string
end

-- remove leading and trailing spaces from string s 
local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end 

-- Request is analysed here

function parse_request(payload, stats)

if deb == 1 
	then  
		amd.print("===========================================================")
		amd.print(string.format('Request size: %d', payload:len()))
	end 


--  reads operation lenght from the binary header
  local Lenght = number(payload, 3, 2)

if deb == 1 
	then
		amd.print(string.format('Lenght:   %d', Lenght+4))
	end

-- Writes diagnostic log if actual payload is longer than first operation size - it means multiple SISNAPI request per single request is included. 
-- This script analyses only first of them. 
	
if deb == 1 
	then
		if payload:len() > Lenght+4 
		then amd.print("Diff") 
		end
	end

-- unrecognized header (will classified as "All Other")
 if payload:len() < Lenght+4 
	then 
		stats:setMonitored(true)
		return 0 
	end 
 
-- payload decripted to utf8
payload_d = utf(payload,Lenght+4)

 
if deb == 1 
	then
		if payload:len() > Lenght+4 
			then 
				payload_f = utf(payload,payload:len())
				amd.print(string.format('Payload complete: %s', payload_f))
		end
		amd.print(string.format('Payload analysed: %s', payload_d))
end

-- recognizes SISNAPI operation name from SISNAPI header ("methodName Request" or "eventName WaitForCmd" in cases I saw
local getMethodName = payload_d:gmatch("(methodName\ +%w+)")
local getEventName = payload_d:gmatch("(eventName\ +%w+)")
MethodName = getMethodName() 

if MethodName == nil 
	then MethodName = getEventName() 
end

if MethodName == nil 
	then MethodName = ""  
end

if deb == 1 
	then
		amd.print(string.format('MethodName: %s', MethodName))
end

local SWECmd = " "
local SWEMethod = " "

-- parses Input Arguments 
local InputArgs = trim(payload_d:sub(125, Lenght+4))

if deb == 1 	
	then
		amd.print(string.format("InputArgs: %s", InputArgs))
end

-- recognizes SWECmd parameter
local getSWECmd = InputArgs:gmatch("(SWECmd=%w+)")
SWECmd = getSWECmd()

if SWECmd == nil 
	then 
		SWECmd = "" 
end

if deb == 1 
	then
		amd.print(string.format("SWECmd: %s" ,SWECmd))
end

-- recognizes SWEMethod parameter
local getSWEMethod = InputArgs:gmatch("(SWEMethod=%w+)")
SWEMethod = getSWEMethod()

if SWEMethod == nil 
	then 
		SWEMethod = "" 
end

if deb == 1 
	then
		amd.print(string.format("SWEMethod: %s" ,SWEMethod))
end

-- recognizes Applet/Viev parameter (SWEView) according to following algorithm:
-- if SWEActiveApplet present use SWEActiveApplet else
-- if SWEActiveView present use SWEActiveView else
-- if SWEApplet present use SWEApplet else
-- if SWEView present use SWEView
-- This is the order recomended by Siebel admin on one of the Siebel POCs I had. Please feel free to modify it to your needs for your purposes.


local getSWEActiveApplet = InputArgs:gmatch("(SWEActiveApplet=%w+)")
local getSWEActiveView = InputArgs:gmatch("(SWEActiveView=%w+)")
local getSWEApplet = InputArgs:gmatch("(SWEApplet=%w+)")
local getSWEView = InputArgs:gmatch("(SWEView=%w+)")

SWEView = getSWEActiveApplet()

if SWEView == nil 
	then 
		SWEView = getSWEActiveView()  
		if SWEView == nil 
			then 
				SWEView = getSWEApplet() 
				if SWEView == nil 
					then
						SWEView = getSWEActiveView()
						if SWEView == nil 
							then
								SWEView = ""
						end
				end
		end
end  

if deb == 1 
	then
		amd.print(string.format("SWEView: %s" ,SWEView))
end

-- "View" is the argument of "SWEView" - just the name of the view that will be passed to Task.
if SWEView ~= "" 
	then 
		local getView=SWEView:gmatch("[^=]+=(%w+)")
		View = getView()
else
	View = ""
end

if deb == 1 
	then
		amd.print(string.format("View: %s" ,View))
end



-- recognizes username, this actually has little practical value because in 12.3 Simple Parser no correlation id can be used 
-- to follow user's session, and all user's sessions goes to single TCP SISNAPI session.

local getUserName = InputArgs:gmatch("SWEUserName=(%w+)")
UserName = getUserName()

if deb == 1 
	then
	if UserName ~= nil 
		then amd.print(string.format("UserName: %s" ,UserName)) 
		else amd.print(string.format("UserName is nil"))
	end
end 

-- concatenate operation name
OperationName = MethodName .. "&" .. SWECmd .. "&" .. SWEMethod .. "&" .. SWEView 

 

-- set OperationName
if  OperationName ~= "" 
  then     
    stats:setOperationName(OperationName, OperationName:len()) 
    if deb == 1 
		then
			amd.print(string.format("OperationName: %s" , OperationName)) 
    end
end 

-- set Task
 if  View ~= ""
	then
		stats:setParameter(4, View, View:len() )
		if deb == 1 
			then
       		amd.print(string.format("Task is : %s" , View))
    	end
	else
		stats:setParameter(4, "Other", 5 )
		if deb == 1 
			then
				amd.print("Task is Other" )
		end

  end

-- set Service
if  SWECmd ~= ""
	then 
		stats:setParameter(6, SWECmd, SWECmd:len() ) 
		if deb == 1 
			then
				amd.print(string.format("Service is : %s" , SWECmd)) 
		end
	else
		stats:setParameter(6, "Other", 5 )
		if deb == 1 
			then
				amd.print("Service is Other" )
		end
 end

 
-- username reporting removed due to reasons mentioned above, you can enable it if you want to see usernames at operations like login. 
-- This can allow you to track numer of active users etc.

-- set UserName 
--  if  UserName ~= nil
--  then
--    stats:setUserName(UserName, UserName:len() )
--    if deb == 1 then
--         amd.print(string.format("UserName is : %s" , UserName))
--    end
--   else 
--    stats:setUserName("", 0)
--   end


-- set Module
 if  SWEMethod ~= ""
	then    
		stats:setParameter(5, SWEMethod, SWEMethod:len() ) 
		if deb == 1 
			then
				amd.print(string.format("Module is : %s" , SWEMethod)) 
		end
	else 
		stats:setParameter(5, "Other", 5 )
		if deb == 1 
			then
				amd.print("Module is Other" )
		end
	end 
     

   stats:setMonitored(true)



  return 0
end



-- response is not analysed here, so no response errors are reported etc. 
-- btw this assumes synchronous protocol, no pipelining is supported in this script version.

function parse_response(payload_r, stats)

--no more than first (payload_max/2) bytes or response string will be analysed only 
local payload_max = 1024
local response_depth = math.min(payload_r:len(),payload_max)
 
payload_resp_d = utf(payload_r, response_depth)

if deb == 1
	then
		amd.print(string.format('Response payload: %s', payload_resp_d))
 	end


-- recognizes SBL Errors parameter
local getSBLError = payload_resp_d:gmatch("(SBL[-][^-]+[-][0-9]+)")
SBLError = getSBLError()

if SBLError ~= nil then

        stats:setAttribute(3, SBLError)
	if deb == 1
		then
        		amd.print(string.format("Attr 3 is : %s" , SBLError))
	end
 end

-- recognizes SBL Errors parameter text
local getSBLErrorText = payload_resp_d:gmatch("SBL[-][^-]+[-][0-9]+:([^*]+)")
SBLErrorText = getSBLErrorText()


if SBLErrorText ~= nil then 
	stats:setAttribute(4, SBLErrorText)
	if deb == 1
		then
			amd.print(string.format("Attr 4 is : %s" , SBLErrorText)) 
	end
 end

return 0
end



--  local the_module = {}
--  the_module.parse_request = parse_request
--  the_module.parse_response = parse_response
--  return the_module



