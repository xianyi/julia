# This file is a part of Julia. License is MIT: http://julialang.org/license

# Tests that do not really go anywhere else

# Test info
@test contains(sprint(io->info(io,"test")), "INFO:")
@test contains(sprint(io->info(io,"test")), "INFO: test")
@test contains(sprint(io->info(io,"test ",1,2,3)), "INFO: test 123")
@test contains(sprint(io->info(io,"test", prefix="MYINFO: ")), "MYINFO: test")

# Test warn
@test contains(sprint(io->Base.warn_once(io,"test")), "WARNING: test")
@test isempty(sprint(io->Base.warn_once(io,"test")))

@test contains(sprint(io->warn(io)), "WARNING:")
@test contains(sprint(io->warn(io, "test")), "WARNING: test")
@test contains(sprint(io->warn(io, "test ",1,2,3)), "WARNING: test 123")
@test contains(sprint(io->warn(io, "test", prefix="MYWARNING: ")), "MYWARNING: test")
@test contains(sprint(io->warn(io, "testonce", once=true)), "WARNING: testonce")
@test isempty(sprint(io->warn(io, "testonce", once=true)))
@test !isempty(sprint(io->warn(io, "testonce", once=true, key=hash("testonce",hash("testanother")))))
let bt = backtrace()
    ws = split(chomp(sprint(io->warn(io,"test", bt))), '\n')
    bs = split(chomp(sprint(io->Base.show_backtrace(io,bt))), '\n')
    @test contains(ws[1],"WARNING: test")
    for (l,b) in zip(ws[2:end],bs)
        @test contains(l, b)
    end
end

# test assert() method
@test_throws AssertionError assert(false)
let res = assert(true)
    @test res === nothing
end
let
    try
        assert(false)
        error("unexpected")
    catch ex
        @test isa(ex, AssertionError)
        @test isempty(ex.msg)
    end
end

# test @assert macro
@test_throws AssertionError (@assert 1 == 2)
@test_throws AssertionError (@assert false)
@test_throws AssertionError (@assert false "this is a test")
@test_throws AssertionError (@assert false "this is a test" "another test")
@test_throws AssertionError (@assert false :a)
let
    try
        @assert 1 == 2
        error("unexpected")
    catch ex
        @test isa(ex, AssertionError)
        @test contains(ex.msg, "1 == 2")
    end
end
# test @assert message
let
    try
        @assert 1 == 2 "this is a test"
        error("unexpected")
    catch ex
        @test isa(ex, AssertionError)
        @test ex.msg == "this is a test"
    end
end
# @assert only uses the first message string
let
    try
        @assert 1 == 2 "this is a test" "this is another test"
        error("unexpected")
    catch ex
        @test isa(ex, AssertionError)
        @test ex.msg == "this is a test"
    end
end
# @assert calls string() on second argument
let
    try
        @assert 1 == 2 :random_object
        error("unexpected")
    catch ex
        @test isa(ex, AssertionError)
        @test !contains(ex.msg,  "1 == 2")
        @test contains(ex.msg, "random_object")
    end
end
# if the second argument is an expression, c
let deepthought(x, y) = 42
    try
        @assert 1 == 2 string("the answer to the ultimate question: ",
                              deepthought(6, 9))
        error("unexpected")
    catch ex
        @test isa(ex, AssertionError)
        @test ex.msg == "the answer to the ultimate question: 42"
    end
end

let # test the process title functions, issue #9957
    oldtitle = Sys.get_process_title()
    Sys.set_process_title("julia0x1")
    @test Sys.get_process_title() == "julia0x1"
    Sys.set_process_title(oldtitle)
    @test Sys.get_process_title() == oldtitle
end


# test gc_enable/disable
@test gc_enable(true)
@test gc_enable(false)
@test gc_enable(false) == false
@test gc_enable(true) == false
@test gc_enable(true)

# test methodswith
immutable NoMethodHasThisType end
@test isempty(methodswith(NoMethodHasThisType))
@test !isempty(methodswith(Int))
immutable Type4Union end
func4union(::Union{Type4Union,Int}) = ()
@test !isempty(methodswith(Type4Union))

# PR #10984
# Disable on windows because of issue (missing flush) when redirecting STDERR.
let
    redir_err = "redirect_stderr(STDOUT)"
    exename = joinpath(JULIA_HOME, Base.julia_exename())
    script = "$redir_err; f(a::Number, b...) = 1;f(a, b::Number) = 1"
    warning_str = readstring(`$exename -f -e $script`)
    @test contains(warning_str, "f(Any, Number)")
    @test contains(warning_str, "f(Number, Any...)")
    @test contains(warning_str, "f(Number, Number)")

    script = "$redir_err; module A; f() = 1; end; A.f() = 1"
    warning_str = readstring(`$exename -f -e $script`)
    @test contains(warning_str, "f()")
end

# lock / unlock
let l = ReentrantLock()
    lock(l)
    unlock(l)
    @test_throws ErrorException unlock(l)
end

# timing macros

# test that they don't introduce global vars
global v11801, t11801, names_before_timing
names_before_timing = names(current_module(), true)

let t = @elapsed 1+1
    @test isa(t, Real) && t >= 0
end

let
    val, t = @timed sin(1)
    @test val == sin(1)
    @test isa(t, Real) && t >= 0
end

# problem after #11801 - at global scope
t11801 = @elapsed 1+1
@test isa(t11801,Real) && t11801 >= 0
v11801, t11801 = @timed sin(1)
@test v11801 == sin(1)
@test isa(t11801,Real) && t11801 >= 0

@test names(current_module(), true) == names_before_timing

# interactive utilities

import Base.summarysize
@test summarysize(Core) > summarysize(Core.Inference) > Core.sizeof(Core)
@test summarysize(Base) > 10_000*sizeof(Int)
module _test_whos_
export x
x = 1.0
end
@test sprint(whos, Main, r"^$") == ""
let v = sprint(whos, _test_whos_)
    @test contains(v, "x      8 bytes  Float64")
end

# issue #13021
let ex = try
    Main.x13021 = 0
    nothing
catch ex
    ex
end
    @test isa(ex, ErrorException) && ex.msg == "cannot assign variables in other modules"
end

@test Base.is_unix(:Darwin)
@test Base.is_unix(:FreeBSD)
@test_throws ArgumentError Base.is_unix(:BeOS)
@unix_only @test Base.windows_version() == (0,0)

# Issue 14173
module Tmp14173
    export A
    A = randn(2000, 2000)
end
whos(IOBuffer(), Tmp14173) # warm up
@test @allocated(whos(IOBuffer(), Tmp14173)) < 10000

## test conversion from UTF-8 to UTF-16 (for Windows APIs)

# empty array
@test utf8_to_utf16(UInt8[]) == UInt16[]

# valid UTF-8 sequences
const V8 = [
    # 1-byte (ASCII)
    ([0x00],[0x0000])
    ([0x0a],[0x000a])
    ([0x7f],[0x007f])
    # 2-byte
    ([0xc0,0x80],[0x0000]) # overlong encoding
    ([0xc2,0x80],[0x0080])
    ([0xc3,0xbf],[0x00ff])
    ([0xc4,0x80],[0x0100])
    ([0xc4,0xa3],[0x0123])
    ([0xdf,0xbf],[0x07ff])
    # 3-byte
    ([0xe0,0xa0,0x80],[0x0800])
    ([0xe0,0xa2,0x9a],[0x089a])
    ([0xe1,0x88,0xb4],[0x1234])
    ([0xea,0xaf,0x8d],[0xabcd])
    ([0xed,0x9f,0xbf],[0xd7ff])
    ([0xed,0xa0,0x80],[0xd800]) # invalid code point – high surrogate
    ([0xed,0xaf,0xbf],[0xdbff]) # invalid code point – high surrogate
    ([0xed,0xb0,0x80],[0xdc00]) # invalid code point – low surrogate
    ([0xed,0xbf,0xbf],[0xdfff]) # invalid code point – low surrogate
    ([0xee,0x80,0x80],[0xe000])
    ([0xef,0xbf,0xbf],[0xffff])
    # 4-byte
    ([0xf0,0x90,0x80,0x80],[0xd800,0xdc00]) # U+10000
    ([0xf0,0x90,0x8d,0x88],[0xd800,0xdf48]) # U+10348
    ([0xf0,0x90,0x90,0xb7],[0xd801,0xdc37]) # U+10437
    ([0xf0,0xa4,0xad,0xa2],[0xd852,0xdf62]) # U+24b62
    ([0xf2,0xab,0xb3,0x9e],[0xda6f,0xdcde]) # U+abcde
    ([0xf3,0xbf,0xbf,0xbf],[0xdbbf,0xdfff]) # U+fffff
    ([0xf4,0x80,0x80,0x80],[0xdbc0,0xdc00]) # U+100000
    ([0xf4,0x8a,0xaf,0x8d],[0xdbea,0xdfcd]) # U+10abcd
    ([0xf4,0x8f,0xbf,0xbf],[0xdbff,0xdfff]) # U+10ffff
]

# invalid UTF-8 sequences
const I8 = [
    # invalid 1-byte sequences
    ([0x80],[0x0080]) # 1 leading ones
    ([0xbf],[0x00bf]) 
    ([0xc0],[0x00c0]) # 2 leading ones
    ([0xdf],[0x00df])
    ([0xe0],[0x00e0]) # 3 leading ones
    ([0xef],[0x00ef])
    ([0xf0],[0x00f0]) # 4 leading ones
    ([0xf7],[0x00f7])
    ([0xf8],[0x00f8]) # 5 leading ones 
    ([0xfb],[0x00fb])
    ([0xfc],[0x00fc]) # 6 leading ones
    ([0xfd],[0x00fd])
    ([0xfe],[0x00fe]) # 7 leading ones
    ([0xff],[0x00ff]) # 8 leading ones
    # other invalid sequences
    ([0xf4,0x90,0xbf,0xbf],[0x00f4,0x0090,0x00bf,0x00bf]
]

for (X,Y,Z) in ((V8,V8,V8), (I8,V8,I8), (V8,I8,V8), (V8,V8,I8), (I8,V8,V8))
    for (a, a′) in X
        @test utf8_to_utf16(a) == a′
        for (b, b′) in Y
            @test utf8_to_utf16([a; b]) == [a′; b′]
            for (c, c′) in Z
                @test utf8_to_utf16([a; b; c]) == [a′; b′; c′]
            end
        end
    end
end

const V16 = filter(V8) do x
    !(length(x[2]) == 1 && 0xd800 <= x[2][1] <= 0xdfff)
end

for (X,Y,Z) in ((V,V,V), (I,V,I), (V,I,V), (V,V,I), (I,V,V))
    for (a, a′) in V
        @test utf16_to_utf8(a′) == a
        # for (b, b′) in V
        #     @test utf16_to_utf8([a′; b′]) == [a; b]
        #     for (c, c′) in V
        #         @test utf16_to_utf8([a′; b′; c′]) == [a; b; c]
        #     end
        # end
    end
end














