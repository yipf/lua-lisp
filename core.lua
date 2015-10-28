
local make_env=function(env,funcs)
	for k,v in pairs(funcs) do
		env[k]=v
	end
	return env
end

quote=function(o)	return o end

local basic_funcs={
	list=function(...)		return {...}	end,
	quote=quote,
}
local ENV=make_env(basic_funcs,math)

print(ENV.list)

local S2table=function(str)
	str=string.gsub(str,"([^%(%s])%s+([^%)%s]-)","%1,%2")
	str=string.gsub(str,"%(","%{")
	str=string.gsub(str,"%)","%}")
	str="return "..str.."nil"
	print(str)
	local func=setfenv(loadstring(str),ENV)
	local t={func()}
	return t
end

local eval
eval=function(t)
	local func
	if type(t)=='table' then 
		func=t[1]
		if func==quote then return t[2] end
		if func then 
			local args={}
			for i=2,#t do				args[i-1]=eval(t[i])			end
			return func(unpack(args))
		end
	end
	return t
end

local str=[[	list (sin 1.0)
]]

local t=S2table(str)
print(t[1],t[2])

print(unpack(eval(t)))

