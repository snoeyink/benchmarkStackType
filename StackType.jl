### A Pluto.jl notebook ###
# v0.19.6

using Markdown
using InteractiveUtils

# ╔═╡ 0c293a30-de93-11ec-281c-a947015d66f9
begin 
	using CommonMark
	using BenchmarkTools
	using DataStructures
end

# ╔═╡ c22b2433-ca55-403d-b103-ba2077833027
cm"
The following uses the C preprocessor to define a lightweight stack with namesp as the stack pointer into array namest[]. I'd like to functions or macros to do the same in Julia with namesp in a register and no bounds checking
```C
// Stack data structure operations  
#define STACKMAX 1000  
#define stkDECLARE(stack,stn) int stack##sp, stack##st[STACKMAX];    
#define stkINIT(stack) {stack##sp = -1; }  
#define PUSH(value, stack) { stack##st[++stack##sp] = value; }  
#define POP(stack) (stack##st[stack##sp--])  
#define isEMPTY(stack) (stack##sp < 0) 
```
"


# ╔═╡ 953cac4c-9f93-4240-9ccd-d16b3db369b5
begin 
	const testT = Int32 # stack entry type
	const STACKMAX = 1000
end

# ╔═╡ c068ee8b-5339-42c4-bdcf-0d43101654f6
cm"""
If I just write the code straight, Julia can keep sp in a register.  
"""

# ╔═╡ 75b9daf9-44c8-415f-a691-94e82b09c806
begin # basic stack
	 function test1(xlist)
		st = zeros(testT,STACKMAX)
		sp = Int32(0)
		for x in xlist
			@inbounds st[sp+=oneunit(sp)] = x # push
		end
		for x in (xlist)
			@inbounds local ret = st[sp] #pop
			sp-=oneunit(sp)
			ret #@assert(ret==x)
		end
		st
	end
	test1(rand(testT,10))
	@benchmark test1(xlist) setup=(xlist=rand(testT, STACKMAX))
end

# ╔═╡ 933b5d55-8241-4b14-8688-6c178558919a
cm"""
Defining a mutable struct type to hold stack pointer and array is slower.
"""

# ╔═╡ 2356aa94-11db-4a7f-9600-3db9ae78599a
begin # basic stack
	 mutable struct Stack2
		st::Vector{testT}
		sp::Int32
		Stack2() = new(zeros(testT,STACKMAX), Int32(0))
	end
	
	function test2(xlist)
		st = Stack2()
@inline	function pop(st::Stack2)::testT
			@inbounds local ret = st.st[st.sp] #pop
			st.sp-=oneunit(st.sp)
			ret
		end
@inline	push!(st::Stack2, x::testT) = @inbounds st.st[st.sp+=oneunit(st.sp)] = x # push
		for x in xlist
			push!(st, x)
		end
		for x in (xlist)
			pop(st) #@assert(pop(st) == x)
		end
		st
	end
	test2(rand(testT,10))
	@benchmark test2(xlist) setup=(xlist=rand(testT, STACKMAX))
end

# ╔═╡ 41ad5033-0b21-4e00-aada-6f4123b5f0f2
cm"""
DataStructures.jl Stack is doing more, including bounds checking and block management for a Deque. It uses a default block of 1024, so for 1000 elements it should use only one block.  Benchmarking twice because variation is high.
"""

# ╔═╡ fc4c0864-44ed-42f2-b726-ca1fe649c945
let 
	global function preallocstack()
		s = Stack{testT}()
		for x in rand(testT, STACKMAX)
			push!(s, x)
		end
		empty!(s)
		s
	end
		
	global function test3(s::Stack, xlist)
		for x in xlist
			@inbounds push!(s, x)
		end
		for x in (xlist)
			@inbounds pop!(s) #@assert(pop(st) == x)
		end
		s
	end

	@benchmark test3(s, xlist) setup=(s=preallocstack(); xlist=rand(testT, STACKMAX))
end

# ╔═╡ de5f326f-6dcf-4d3f-b0ac-829d16508bc9
@benchmark test3(s, xlist) setup=(s=preallocstack(); xlist=rand(testT, STACKMAX))

# ╔═╡ c9909579-a61c-4f76-b7a6-b5c928d0baba
cm"""
Macros defined below wind up being Boxed variables, so this is doing allocations and runtime type checking. Is there a way to write the macros to avoid this?  
"""

# ╔═╡ ed55cd7a-59d2-4ce1-a573-7d5cc2d3b66c
begin # stack
	macro stdeclare(stackname)
		:(local $(esc(Symbol("$(stackname)st")))::Vector{testT} = zeros(testT,STACKMAX))
	end
	macro stinit!(stackname)
		:(local $(esc(Symbol("$(stackname)sp")))::Int32 = 0)
	end
	macro stisempty(stackname)
		:($(esc(Symbol("$(stackname)sp")))::Int32 ≤ 0)
	end
	macro stpop!(stackname)
		quote
			local ret::testT = $(esc(Symbol("$(stackname)st")))[$(esc(Symbol("$(stackname)sp")))::Int32]; 
			$(esc(Symbol("$(stackname)sp")))::Int32-=oneunit(Int32); 
			ret
		end
	end
	macro stpush!(stackname, value)
		:($(esc(Symbol("$(stackname)st")))[$(esc(Symbol("$(stackname)sp")))::Int32+=oneunit(Int32)]::testT = $(esc(value))::testT)
	end
end     

# ╔═╡ 5edf2ca6-03e4-45ad-bb86-0de863cf5e8d
let
	global function stacktest(xlist)
		@stdeclare(test)
		@stinit!(test)
		for x in xlist
			@stpush!(test, x)
		end
		for x in (xlist)
			@stpop!(test) #@assert(@stpop!(test)==x)
		end
	end
	@benchmark stacktest(xlist) setup=(xlist=rand(testT, STACKMAX))
end 

# ╔═╡ 4c8d5106-68a0-4e46-a5bb-bd29bcf62250
cm"""
Main difference between using st/sp and putting them in a struct is the extra getfield for the sp.  
"""

# ╔═╡ dee12066-263d-4aee-b040-25954465b597
@code_typed(test1(rand(testT, 1000)))

# ╔═╡ 35e9d8b3-a505-472c-9030-34530c521e45
@code_typed(test2(rand(testT, 1000)))

# ╔═╡ c6632dfe-1642-480d-ac88-00bdb4d910ec
cm"""
DataStructures.jl Stack is actually using a blocked Deque.  We'll need only one block. 
"""

# ╔═╡ faa0e151-7135-456e-a731-cb604828412d
@code_typed(test3(preallocstack(), rand(testT, 1000)))

# ╔═╡ e4d64067-5d6e-47c0-b572-3a26a7932655
cm"""
Lots of Box and Any here.  Is it not possible for a macro expansion to define variables in a module scope?
"""

# ╔═╡ 89f5867a-e963-40c0-bfa3-1525bff3ce7a
@code_typed(stacktest(rand(testT, 1000)))

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CommonMark = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
DataStructures = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"

[compat]
BenchmarkTools = "~1.3.1"
CommonMark = "~0.8.6"
DataStructures = "~0.18.13"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.3"
manifest_format = "2.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "4c10eee4af024676200bc7752e536f858c6b8f93"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.1"

[[deps.CommonMark]]
deps = ["Crayons", "JSON", "URIs"]
git-tree-sha1 = "4cd7063c9bdebdbd55ede1af70f3c2f48fab4215"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "0.8.6"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "924cdca592bc16f14d2f7006754a621735280b74"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.1.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "1285416549ccfcdf0c50d4997a94331e88d68413"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
"""

# ╔═╡ Cell order:
# ╠═0c293a30-de93-11ec-281c-a947015d66f9
# ╟─c22b2433-ca55-403d-b103-ba2077833027
# ╠═953cac4c-9f93-4240-9ccd-d16b3db369b5
# ╟─c068ee8b-5339-42c4-bdcf-0d43101654f6
# ╠═75b9daf9-44c8-415f-a691-94e82b09c806
# ╟─933b5d55-8241-4b14-8688-6c178558919a
# ╠═2356aa94-11db-4a7f-9600-3db9ae78599a
# ╟─41ad5033-0b21-4e00-aada-6f4123b5f0f2
# ╠═fc4c0864-44ed-42f2-b726-ca1fe649c945
# ╠═de5f326f-6dcf-4d3f-b0ac-829d16508bc9
# ╠═c9909579-a61c-4f76-b7a6-b5c928d0baba
# ╠═5edf2ca6-03e4-45ad-bb86-0de863cf5e8d
# ╠═ed55cd7a-59d2-4ce1-a573-7d5cc2d3b66c
# ╟─4c8d5106-68a0-4e46-a5bb-bd29bcf62250
# ╠═dee12066-263d-4aee-b040-25954465b597
# ╠═35e9d8b3-a505-472c-9030-34530c521e45
# ╟─c6632dfe-1642-480d-ac88-00bdb4d910ec
# ╠═faa0e151-7135-456e-a731-cb604828412d
# ╟─e4d64067-5d6e-47c0-b572-3a26a7932655
# ╠═89f5867a-e963-40c0-bfa3-1525bff3ce7a
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
