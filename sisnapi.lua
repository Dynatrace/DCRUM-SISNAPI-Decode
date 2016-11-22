

require 'amd'

local little_endian_factors = {1, 256, 65536, 4294967296}
local big_endian_factors = {4294967296, 65536, 256, 1}

local ASYNC_MESSAGE_TYPE = 34
local REQUEST_MESSAGE_TYPE = 35
local REPLY_MESSAGE_TYPE = 36

-- local HEADER_SIZE_1 = 0x18
local HEADER_SIZE_1 = 4

local HEADER_SIZE_2 = 0x04

local MESSAGE_SIZE_OFFSET = 10


-- see yaha::Direction enumeration on C++ side
local DIRECTION = {C2S=0, S2C=1}

local function unpack_integer4(pstr, offset, is_little_endian)
    --  struct.unpack("I4", pstr:sub(offset, offset + 4))
    local factors = (is_little_endian and little_endian_factors) or big_endian_factors
    return (pstr:byte(offset) * factors[1]) +
        (pstr:byte(offset + 1) * factors[2]) +
        (pstr:byte(offset + 2) * factors[3]) +
        (pstr:byte(offset + 3) * factors[4])
end

local function unpack_short(pstr, offset)
    --  struct.unpack(">I2", pstr:sub(offset, offset + 2))
    return (pstr:byte(offset) * 256) + (pstr:byte(offset + 1))
end

local function bit(p)
    return 2 ^ (p - 1)  -- 1-based indexing
end

local function HexDumpString(str)
  return (string.gsub(str,"(.)", function (c) return
    string.format("%02X%s",string.byte(c), "")
  end ) )
end


-- Typical call:  if hasbit(x, bit(3)) then ...
local function hasbit(x, p)
    return x % (p + p) >= p
end

local function print_hex(pstr, offset, len)
    for idx, el in ipairs({pstr:byte(offset, offset + len)}) do
        amd.print(idx + " " + string.format('0x%0x', el))
    end
end

-- convert utf16 to utf8, ignors non-ASCII chars
local function utf(parr,max)

    local out_string = ""
    for i = 1, max
                do
                        if i % 2 == 0
                        then


 				if (string.byte(parr:sub(i,i)) == 0x20 or string.byte(parr:sub(i,i)) < 0x1F)
				then 
 				out_string = out_string .. "_"
				else
 				out_string = out_string .. (parr:sub(i,i))
				end
			end

                end
        return out_string
end


--
-- public functions:
--

-- script name --
function script_name()
    return "SisnapiParser"
end

-- define tables for message handlers
SisnapiMessageHandler = {}
SisnapiSessionHandler = {}


function messageHandlers()
    return {"SisnapiMessageHandler", "SisnapiSessionHandler"}
end


function SisnapiMessageHandler.parseMessage(messageHandler)
    local block = messageHandler:currentBlock()

 --amd.print(string.format("Block_lenght: %d", block:lenght()))
    
    if block:length() < HEADER_SIZE_1  then 
-- amd.print(string.format("Message too short"))
        -- message too short
        messageHandler:needMore(HEADER_SIZE_1)
-- amd.print(string.format("Need More - Header too small"))
        return
    end
    local payload = block:c_str() 
    
-- amd.print(string.format("Payload_size: %d", payload:len()))

	local payload_hex = HexDumpString(payload)
--	amd.print(string.format("Payload_hex: %s", payload_hex))
--       amd.print(string.format("Payload: %s", payload))

    
    --local payload = xt
    
    --endianess !!
    -- = hasbit(payload:byte(MESSAGE_FLAGS_OFFSET), bit(1))
    local isLittleEndian = false
    
    
    local messageSize = unpack_short(payload, 3, isLittleEndian)
 -- amd.print(string.format("Message_size: %d",messageSize))


    if payload:len() < messageSize + HEADER_SIZE_2  then
        -- message too short
        messageHandler:needMore(messageSize + HEADER_SIZE_2)
 -- amd.print(string.format("Need More - we need totaly bytes : %d", messageSize + HEADER_SIZE_2))
        return
    end
-- amd.print(string.format("Payload_hex: %s", payload_hex))

    messageHandler:messageComplete(messageSize + HEADER_SIZE_2)
    
    if messageSize < HEADER_SIZE_1 then
      messageHandler:setNoise()
      return
    end
    
    
    
    local requestId = payload:sub(15,16)
  local requestid_hex = HexDumpString(payload:sub(15,16))
   --     amd.print(string.format("Requestid_hex: %s", requestid_hex))

messageHandler:setMsgState('requestId',requestid_hex)
    
    --amd.print(string.format("Msg len: %d %d %s",messageSize+ HEADER_SIZE_1, payload:len(), requestId))
    messageHandler:setYahaSessionId(requestid_hex)
    messageHandler:pushNextLayerRange(0, messageSize+ 4)
end


function SisnapiMessageHandler.processDirectionSwitch(messageHandler)

end


function SisnapiMessageHandler.trySync(inBlock, outBlock, resyncDirChangedCnt)
    local payload = inBlock:c_str()
    if payload:len() < HEADER_SIZE_1 then
      return false
    end
    local s = payload:sub(21, 24) 
    local s_hex = HexDumpString(payload:sub(21,24))
--     amd.print(string.format("trysync s_hex: %s", s_hex))
    if s_hex == '00000001' then
        return true
    end
    return false;
end


function SisnapiSessionHandler.parseMessage(messageHandler)    
    local block = messageHandler:currentBlock()
    messageHandler:messageComplete(block:length()) 
             -- No more chunks needed         
    --messageHandler:pushNextLayerRange(HEADER_SIZE_1+HEADER_SIZE_2, block:length()-(HEADER_SIZE_1+HEADER_SIZE_2))
    
    
    
    local payload = block:c_str()
  
-- message type below - 01 - request, 02 response, 05 error 
  local se = payload:sub(21, 24)
  local se_hex = HexDumpString(payload:sub(21,24))
 
    
    messageHandler:pushNextLayerRange(0, block:length())
    if (se_hex == '00000002' or se_hex == '00000005') then
		messageHandler:setResponse(true)
		messageHandler:setLast(true)
    elseif se_hex == '00000001' then
		messageHandler:setRequest(true)
    end
    
    
    
end


function SisnapiSessionHandler.processDirectionSwitch(messageHandler)

end

-- no need to syns session on SessionHandler level
function SisnapiSessionHandler.trySync(inBlock, outBlock, resyncDirChangedCnt) -- > nie probuj juz synchronizowac
    return true
end


function parse_request(payload, hit, state)
    
local key = state:getMsgState('requestId',0)
-- amd.print(string.format("requ_requestId: %s", key))
hit:setCorrelationId(key, key:len())
    
    local isLittleEndian = false
    
-- local request_hex = HexDumpString(payload)
-- amd.print(string.format("request_hex: %s", request_hex))

    local messageSize = unpack_short(payload, 3, isLittleEndian)

-- data start here     
    local pos = 89
if messageSize < pos then return 0 end

-- first operation name (op1) lenght
    local op_len =  unpack_integer4(payload, pos, false)	
-- amd.print(string.format("op1_len: %d", op_len))

	pos = pos + 4
if messageSize < pos+op_len then return 0 end

-- first operation name (op1) lenght
    local op1 = payload:sub(pos, pos+op_len-3)
-- local op1_hex = HexDumpString(op1)

-- now we need to convert UTF 16 coced string into UTF8 (_d - descypted)
local op1_d = utf(op1,op1:len())

-- amd.print(string.format("op1_hex : %s", op1_hex))
-- amd.print(string.format("op1_d : %s", op1_d))

pos = pos + op_len +4
op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op2_len: %d", op_len))
pos = pos + 4
local op2 = payload:sub(pos, pos+op_len-3)
local op2_d = utf(op2,op2:len())
-- amd.print(string.format("op2_d : %s", op2_d))

pos = pos + op_len 
op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op3_len: %d", op_len))
pos = pos + 4
local op3 = payload:sub(pos, pos+op_len-3)
local op3_d = utf(op3,op3:len())
-- amd.print(string.format("op3_d : %s", op3_d))

pos = pos + op_len +4
op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op4_len: %d", op_len))
pos = pos + 4
local op4 = payload:sub(pos, pos+op_len-3)

local op4_d = utf(op4,op4:len())
-- amd.print(string.format("op4_d : %s", op4_d))

-- local op4_d_hex = HexDumpString(op4_d)
-- amd.print(string.format("op4_d_hex: %s", op4_d_hex))



pos = pos + op_len
op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op5_len: %d", op_len))
pos = pos + 4
local op5 = payload:sub(pos, pos+op_len-3)
local op5_d = utf(op5,op5:len())
-- amd.print(string.format("op5_d : %s", op5_d))


pos = pos + op_len +4
op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op6_len: %d", op_len))
pos = pos + 4
local op6 = payload:sub(pos, pos+op_len-3)
local op6_d = utf(op6,op6:len())
-- amd.print(string.format("op6_d : %s", op6_d))




-- recognizes SWEMethod parameter from op6_d
local getSWEMethod = op6_d:gmatch("(SWEMethod=%w+)")
SWEMethod = getSWEMethod()

if SWEMethod == nil
        then
                SWEMethod = "Other"
end


-- recognizes SWECmd parameter
local getSWECmd = op6_d:gmatch("(SWECmd=%w+)")
SWECmd = getSWECmd()

if SWECmd == nil
        then
                SWECmd = "Other"
end

-- recognizes Applet/Viev parameter (SWEView) according to following algorithm:
-- if SWEActiveApplet present use SWEActiveApplet else
-- if SWEActiveView present use SWEActiveView else
-- if SWEApplet present use SWEApplet else
-- if SWEView present use SWEView
-- This is the order recomended by Siebel admin on one of the Siebel POCs I had. Please feel free to modify it to your needs for your purposes.


local getSWEActiveApplet = op6_d:gmatch("(SWEActiveApplet=%w+)")
local getSWEActiveView = op6_d:gmatch("(SWEActiveView=%w+)")
local getSWEApplet = op6_d:gmatch("(SWEApplet=%w+)")
local getSWEView = op6_d:gmatch("(SWEView=%w+)")

SWEView = getSWEActiveApplet()

if SWEView == nil
        then
                SWEView = getSWEActiveView()
                if SWEView == nil
                        then
                                SWEView = getSWEApplet()
                                if SWEView == nil
                                        then
                                                SWEView = getSWEView()
                                                if SWEView == nil
                                                        then
                                                                SWEView = "Other"
                                                end
                                end
                end
end

local param6 = SWECmd
local param5 = SWEMethod
local param4 = SWEView

-- amd.print(string.format("param6: %s", param6))
-- amd.print(string.format("param5: %s", param5))
-- amd.print(string.format("param4: %s", param4))
-- amd.print(string.format("Attrib0: %s", Attrib0))

hit:setParameter(4, param4, param4:len())
hit:setParameter(5, param5, param5:len())
hit:setParameter(6, param6, param6:len())

OperationName = op4_d .. "&" .. SWECmd .. "&" .. SWEMethod .. "&" .. SWEView
	
    -- hit:setOperationName(operation_name, operation_name:len())
    -- operation_name = payload:sub(operation_name_offset, operation_name_offset + operation_length - 2)
   -- amd.print(string.format("operation_name: %s", operation_name))

local operation_name = OperationName
-- amd.print(string.format("operation_name: %s", operation_name))

    hit:setOperationName(operation_name, operation_name:len())
    return 0
end

function parse_response(payload, hit, state)

-- local response_hex = HexDumpString(payload)
-- amd.print(string.format("response_hex: %s", response_hex))

    local isLittleEndian = false

-- local key = state:getMsgState('requestId',0)
-- amd.print(string.format("resp_requestId: %s", key))


    local messageSize = unpack_short(payload, 3, isLittleEndian)


    
-- local request_hex = HexDumpString(payload)
-- amd.print(string.format("request_hex: %s", request_hex))

-- recognition response code below (2 - response, 5 - error)
 local error = unpack_short(payload, 23)
 -- amd.print(string.format("Error: %d", error))
 
if error == 2 then return 0 end

    local pos = 65
    local op_len =  unpack_integer4(payload, pos, false)	
-- amd.print(string.format("op1_len: %d", op_len))
--local op_len_hex = HexDumpString(op_len)
--amd.print(string.format("op_len_hex: %s", op_len_hex))

pos = pos + 4
local op1 = payload:sub(pos, pos+op_len-3)
local op1_hex = HexDumpString(op1)

local op1_d = utf(op1,op1:len())

hit:setAttribute(0, op1_d, op1_d:len())


-- amd.print(string.format("resp op1_d : %s", op1_d))

pos = pos + op_len +16
if messageSize < pos then return 0 end

op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op2_len: %d", op_len))
pos = pos + 4
if messageSize < pos then return 0 end

local op2 = payload:sub(pos, pos+op_len-3)
local op2_d = utf(op2,op2:len())
-- amd.print(string.format("resp op2_d : %s", op2_d))

hit:setAttribute(1, op2_d, op2_d:len())

pos = pos + op_len +12
if messageSize < pos then return 0 end

op_len =  unpack_integer4(payload, pos, false)
local op3_len_hex = HexDumpString(op_len)
pos = pos + 4
if messageSize < pos then return 0 end

local op3 = payload:sub(pos, pos+op_len-3)
local op3_d = utf(op3,op3:len())
-- amd.print(string.format("resp op3_d : %s", op3_d))

hit:setAttribute(2, op3_d, op3_d:len())

pos = pos + op_len +12
if messageSize < pos then return 0 end

op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op4_len: %d", op_len))
pos = pos + 4
if messageSize < pos then return 0 end

local op4 = payload:sub(pos, pos+op_len-3)

local op4_d = utf(op4,op4:len())
-- amd.print(string.format("resp op4_d : %s", op4_d))
hit:setAttribute(3, op4_d, op4_d:len())




pos = pos + op_len +12
if messageSize < pos then return 0 end

op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op4_len: %d", op_len))
pos = pos + 4
if messageSize < pos then return 0 end

local op5 = payload:sub(pos, pos+op_len-3)

local op5_d = utf(op5,op5:len())
-- amd.print(string.format("resp op5_d : %s", op5_d))



pos = pos + op_len +12
if messageSize < pos then return 0 end

op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op6_len: %d", op_len))
pos = pos + 4
if messageSize < pos then return 0 end

local op6 = payload:sub(pos, pos+op_len-3)

local op6_d = utf(op6,op6:len())
-- amd.print(string.format("resp op6_d : %s", op6_d))






pos = pos + op_len +12
if messageSize < pos then return 0 end

op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op7_len: %d", op_len))
pos = pos + 4
if messageSize < pos then return 0 end

local op7 = payload:sub(pos, pos+op_len-3)

local op7_d = utf(op7,op7:len())
-- amd.print(string.format("resp op7_d : %s", op7_d))








-- amd.print(string.format("op1_hex : %s", op1_hex))
-- amd.print(string.format("resp_op1_d : %s", op1_d))

--if error ~= 5 then 

--pos = pos + op_len +4
--op_len =  unpack_integer4(payload, pos, false)
-- amd.print(string.format("op2_len: %d", op_len))
--pos = pos + 4
--local op2 = payload:sub(pos, pos+op_len-3)
--local op2_d = utf(op2,op2:len())
--amd.print(string.format("op2_d : %s", op2_d))

--end



    return 0


end


-- local the_module = {}
-- the_module.parse_request = parse_request
-- the_module.parse_response = parse_response
-- return the_module
