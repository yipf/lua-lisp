local type,tostring=type,tostring
local format,gsub,concat=string.format,string.gsub,table.concat

--------------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------------

local str2atom=function(str)
	str=string.gsub(str,[[\(.)]],"%1")
	return tonumber(str) or str
end

local push=table.insert
local append_element=function(list,element,quote_count) 	-- append element to a list corsidering the count of quote 
	quote_count=quote_count or 0
	for i=1,quote_count do
		element={str2atom("quote"),element}
	end
	table.insert(list,element)
	return 0
end

local sexp2table
sexp2table=function(sexp,s,e,t)
	s,e,t=s or 1,e or string.len(sexp), t or {}
	local append_element,match,sub=append_element,string.match,string.sub
	local ch,list
	local ss,out_quote,quote_count=s,true,0 -- label the substring start point
	local out_quote=true
	while s<=e do
		ch=sub(sexp,s,s)
		if ch==")" and out_quote then
			if ss<s then quote_count=append_element(t,str2atom(sub(sexp,ss,s-1),"ATOM"),quote_count) 	end
			return t,s+1
		elseif ch=="(" and out_quote then
			if ss<s then quote_count=append_element(t,str2atom(sub(sexp,ss,s-1),"ATOM"),quote_count) end
			list,s=sexp2table(sexp,s+1,e)
			quote_count=append_element(t,list,quote_count)
			ss=s
		elseif ch=="`" and out_quote then
			quote_count=quote_count+1
			s=s+1
			ss=s
		elseif ch=="\"" then
			if ss<s then quote_count=append_element(t,str2atom(sub(sexp,ss,s-1),out_quote and "ATOM" or "STRING" ),quote_count) end
			out_quote=not out_quote -- update the status of 'out_quote'
			s=s+1
			ss=s
		elseif ch=="\\" then
			s=s+2
		elseif match(ch,"%s") then -- if ch is a space character
			if out_quote then 
				if ss<s then quote_count=append_element(t,str2atom(sub(sexp,ss,s-1),"ATOM"),quote_count) end	
				ss=s+1
			end
			s=s+1
		else
			s=s+1
		end
	end
	if ss<s then quote_count=append_element(t,str2atom(sub(sexp,ss,s-1),"ATOM"),quote_count) end
	return t,s
end

--------------------------------------------------------------------------------------
-- output
--------------------------------------------------------------------------------------

local atom2str=function(atom)
	local tp=type(atom)
	return tp=="string" and string.match(atom,"%s") and format("%q",atom) or tostring(atom)
end

local obj2sexp
obj2sexp=function(obj,sep)
	sep=sep or " "
	if type(obj)~='table' then 
		return atom2str(obj)
	end
	local t={}
	for i,v in ipairs(obj) do		t[i]=obj2sexp(v)	end
	return format("(%s)",concat(t,sep))
end

--------------------------------------------------------------------------------------
-- eval
--------------------------------------------------------------------------------------

local clone
clone=function(src,dst)
	if type(src)~="table" then return src	end
	dst=dst or {}
	for k,v in pairs(src) do		dst[k]=v	end
	return dst
end

local currying
currying=function(key,value,body)
	if type(body)~="table" then return body==key and clone(value) or clone(body) end
	body=clone(body) -- construct new body
	for i,v in ipairs(body) do
		body[i]=currying(key,value,v)
	end
	return body
end

local apply_args
apply_args=function(inputs,args,body)
	assert(#inputs>=#args,"#"..(#inputs+1).." argument not defined!")
	for i,v in ipairs(args) do
		body=currying(v,inputs[i],body)
	end
	return body
end

local eval
eval=function(obj,env,level)
	level=level or 0
	obj,env=clone(obj),env or _G
	local tp=type(obj)
	if tp~="table" then
		if tp=="string" then
			return env[obj] or obj
		else 
			return obj
		end
	end
	-- process list
	local first=obj[1]
	-- process `quote' , `lambda' and `macro' 
	if first=="quote" then
		return obj[2]
	elseif first=="lambda" or first=="macro" then
		return obj
	end
	-- nomal processing
	local rest={unpack(obj,2)}
	first=eval(first,env)
	tp=type(first)
	if tp=="function" then		
		for i,v in ipairs(rest) do	rest[i]=eval(v,env)	end
		return first(unpack(rest))
	elseif tp=="table" then
		local vfirst=first[1]
		if vfirst=="lambda" then
			for i,v in ipairs(rest) do rest[i]=eval(v,env,level+1)	end
			return eval(apply_args(rest,first[2],first[3]),env,level+1)
		elseif vfirst=="macro" then
			return eval(apply_args(rest,first[2],first[3]),env,level+1)
		end
	end
	for i,v in ipairs(obj) do	obj[i]=eval(v,env)	end
	return obj
end

--------------------------------------------------------------------------------------
-- register system function
--------------------------------------------------------------------------------------

register_funcs=function(func_sets,env)
	env=env or {}
	for i,func_set in ipairs(func_sets) do
		env=clone(func_set,env)
	end
	return env
end

local env=register_funcs{_G,math}

local basic_funcs={
	['+']=function(a,b) return a+b end,
	['-']=function(a,b) return a-b end,
	['*']=function(a,b) return a*b end,
	['/']=function(a,b) return a/b end,
	['set']=function(k,v) env[k]=v return k end,
	['lambda']=function(args,body)		return {"lambda",args,body}	end,
	['macro']=function(args,body)		return {"macro",args,body}	end,
}

env=clone(basic_funcs,env)


------- test pack

local eval_sexp=function(str)
	local t=sexp2table(str)
	local tt=eval(t,env)
	print(string.rep("=",100))
	print(str)
	print("=",obj2sexp(t))
	print("=",obj2sexp(tt,"\n"))
end


local S=[[(a b "aaa ccc vvv (a)" (3.14   b c))]]
local S=[[a b "aaa ccc vvv \" (a)" (3.14   b c)]]
local S=[[a b "aaa ccc vvv \" (a)" 'v '(3.14   'b c d)  (a b) (sin 3.0) ]]
local S=[[
(set `defmacro 
	(macro (name args body) 
		(set name (macro args body))
	)
)

(set `defunc
	(macro (name args body) 
		(set name (lambda args body))
	)
)

defmacro

(defmacro `m (x) (sin x))
m

defunc
(defunc `s (x) (sin x))
s
(m 2.0)
(s 2.0)
(sin 2.0)
(m 2.0)
(m 2.0)
(s 2.0)
(s 2.0)
]]

eval_sexp(S)

