local type,tostring=type,tostring
local format,gsub,concat=string.format,string.gsub,table.concat

--------------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------------

local default_atoms={
	quote={TYPE="ATOM",VALUE="quote"},
	TRUE={TYPE="ATOM",VALUE="TURE"},
	FALSE={TYPE="ATOM",VALUE="FALSE"},
}

local str2atom=function(str,tp)
	local v= tonumber(str)
	if v then return {TYPE="NUMBER",VALUE=v}	end
	return default_atoms[str] or {TYPE=tp or "ATOM",VALUE=string.gsub(str,[[\(.)]],"%1")}
end

local push=table.insert
local append_element=function(list,element,quote_count) 	-- append element to a list corsidering the count of quote 
	quote_count=quote_count or 0
	for i=1,quote_count do
		element={TYPE="LIST",str2atom("quote"),element}
	end
	table.insert(list,element)
	return 0
end

local sexp2table
sexp2table=function(sexp,s,e,t)
	s,e,t=s or 1,e or string.len(sexp), t or {TYPE="LIST"}
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
		elseif ch=="'" and out_quote then
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
	local tp=atom.TYPE
	return tp=="STRING" and format("%q",atom.VALUE) or tostring(atom.VALUE)
end

local obj2sexp
obj2sexp=function(obj)
	if obj.TYPE~="LIST" then 
		return atom2str(obj)
	end
	local t={}
	for i,v in ipairs(obj) do		t[i]=obj2sexp(v)	end
	return format("(%s)",concat(t," "))
end

--------------------------------------------------------------------------------------
-- eval
--------------------------------------------------------------------------------------

local clone
clone=function(src,dst)
	if type(src)~="table" then return src	end
	local dst={}
	for k,v in pairs(src) do		dst[k]=v	end
	return dst
end

local eval
eval=function(obj,env)
	obj,env=clone(obj),env or _G
	if obj.TYPE~="LIST" then
		if obj.TYPE=="ATOM" then
			return env[obj.VALUE]
		else 
			return obj
		end
	end
	for i,v in ipairs(obj) do		obj[i]=eval(v)	end
	local v=obj[1]
	if type(v)=="function" then
		
	elseif v.TYPE=="lambda" then
		
	elseif v.TYPE=="macro" then
		
	end
end

--------------------------------------------------------------------------------------
-- register system function
--------------------------------------------------------------------------------------

local register_sys_func=function(name,func,env)
	n=n or 0
	env[name]={}
end


------- test pack

local S=[[(a b "aaa ccc vvv (a)" (3.14   b c))]]
local S=[[a b "aaa ccc vvv \" (a)" (3.14   b c)]]
local S=[[a b "aaa ccc vvv \" (a)" 'v '(3.14   'b c d)  (a b)  ]]

local t,s=sexp2table(S)



--~ t=unpack(t)
print("S=",obj2sexp(t))

