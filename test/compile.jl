# This file is a part of Julia. License is MIT: http://julialang.org/license

using Base.Test

olderr = STDERR
dir = mktempdir()
insert!(LOAD_PATH, 1, dir)
insert!(Base.LOAD_CACHE_PATH, 1, dir)
Foo_module = :Foo4b3a94a1a081a8cb
try
    Foo_file = joinpath(dir, "$Foo_module.jl")

    open(Foo_file, "w") do f
        print(f, """
              __precompile__(true)
              module $Foo_module
              @doc "foo function" foo(x) = x + 1
              include_dependency("foo.jl")
              include_dependency("foo.jl")
              module Bar
              @doc "bar function" bar(x) = x + 2
              include_dependency("bar.jl")
              end
              end
              """)
    end

    # Issue #12623
    @test __precompile__(true) === nothing

    Base.require(Foo_module)
    cachefile = joinpath(dir, "$Foo_module.ji")

    # use _require_from_serialized to ensure that the test fails if
    # the module doesn't load from the image:
    try
        rd, wr = redirect_stderr()
        @test nothing !== Base._require_from_serialized(myid(), Foo_module, true)
    finally
        redirect_stderr(olderr)
    end

    let Foo = eval(Main, Foo_module)
        @test Foo.foo(17) == 18
        @test Foo.Bar.bar(17) == 19

        # issue #12284:
        @test stringmime("text/plain", Base.Docs.doc(Foo.foo)) == "foo function\n"
        @test stringmime("text/plain", Base.Docs.doc(Foo.Bar.bar)) == "bar function\n"

        deps = Base.cache_dependencies(cachefile)
        @test sort(deps[1]) == map(s -> (s, Base.module_uuid(eval(s))),
                                   [:Base,:Core,:Main])
        @test map(x -> x[1], sort(deps[2])) == [Foo_file,joinpath(dir,"bar.jl"),joinpath(dir,"foo.jl")]
    end

    Baz_file = joinpath(dir, "Baz.jl")
    open(Baz_file, "w") do f
        print(f, """
              __precompile__(false)
              module Baz
              end
              """)
    end
    try
        rd, wr = redirect_stderr()
        Base.compilecache("Baz") # from __precompile__(false)
        error("__precompile__ disabled test failed")
    catch exc
        redirect_stderr(olderr)
        isa(exc, ErrorException) || rethrow(exc)
        search(exc.msg, "__precompile__(false)") == 0 && rethrow(exc)
    end

    # Issue #12720
    FooBar_file = joinpath(dir, "FooBar.jl")
    open(FooBar_file, "w") do f
        print(f, """
              __precompile__(true)
              module FooBar
              end
              """)
    end
    Base.compilecache("FooBar")
    sleep(2)
    open(FooBar_file, "w") do f
        print(f, """
              __precompile__(true)
              module FooBar
              error("break me")
              end
              """)
    end

    try
        rd, wr = redirect_stderr()
        Base.require(:FooBar)
        error("\"LoadError: break me\" test failed")
    catch exc
        redirect_stderr(olderr)
        isa(exc, ErrorException) || rethrow(exc)
        search(exc.msg, "ERROR: LoadError: break me") == 0 && rethrow(exc)
    end
finally
    if STDERR != olderr
        redirect_stderr(olderr)
    end
    splice!(Base.LOAD_CACHE_PATH, 1)
    splice!(LOAD_PATH, 1)
    rm(dir, recursive=true)
end

# test --compilecache=no command line option
dir = mktempdir()
let dir = mktempdir(),
    Time_module = :Time4b3a94a1a081a8cb

    try
        open(joinpath(dir, "$Time_module.jl"), "w") do io
            write(io, """
            module $Time_module
                __precompile__(true)
                time = Base.time()
            end
            """)
        end

        eval(quote
            insert!(LOAD_PATH, 1, $(dir))
            insert!(Base.LOAD_CACHE_PATH, 1, $(dir))
            Base.compilecache(:Time4b3a94a1a081a8cb)
        end)

        exename = `$(joinpath(JULIA_HOME, Base.julia_exename())) --precompiled=yes`

        testcode = """
            insert!(LOAD_PATH, 1, $(repr(dir)))
            insert!(Base.LOAD_CACHE_PATH, 1, $(repr(dir)))
            using $Time_module
            getfield($Time_module, :time)
        """

        t1_yes = readchomp(`$exename --compilecache=yes -E $(testcode)`)
        t2_yes = readchomp(`$exename --compilecache=yes -E $(testcode)`)
        @test t1_yes == t2_yes

        t1_no = readchomp(`$exename --compilecache=no -E $(testcode)`)
        t2_no = readchomp(`$exename --compilecache=no -E $(testcode)`)
        @test t1_no != t2_no
        @test parse(Float64, t1_no) < parse(Float64, t2_no)

    finally
        splice!(Base.LOAD_CACHE_PATH, 1)
        splice!(LOAD_PATH, 1)
        rm(dir, recursive=true)
    end
end
