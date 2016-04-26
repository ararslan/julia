# This file is a part of Julia. License is MIT: http://julialang.org/license

## low-level pcre2 interface ##

module PCRE

include(string(length(Core.ARGS)>=2?Core.ARGS[2]:"","pcre_h.jl"))  # include($BUILDROOT/base/pcre_h.jl)

const PCRE_LIB = "libpcre2-8"

global JIT_STACK = C_NULL
global MATCH_CONTEXT = C_NULL

function __init__()
    try
        JIT_STACK_START_SIZE = 32768
        JIT_STACK_MAX_SIZE = 1048576
        global JIT_STACK = ccall((:pcre2_jit_stack_create_8, PCRE_LIB), Ptr{Void},
                                 (Cint, Cint, Ptr{Void}),
                                 JIT_STACK_START_SIZE, JIT_STACK_MAX_SIZE, C_NULL)
        global MATCH_CONTEXT = ccall((:pcre2_match_context_create_8, PCRE_LIB),
                                     Ptr{Void}, (Ptr{Void},), C_NULL)
        ccall((:pcre2_jit_stack_assign_8, PCRE_LIB), Void,
              (Ptr{Void}, Ptr{Void}, Ptr{Void}), MATCH_CONTEXT, C_NULL, JIT_STACK)
    catch ex
        Base.showerror_nostdio(ex,
            "WARNING: Error during initialization of module PCRE")
    end
end

# supported options for different use cases

const COMPILE_MASK      =
      ANCHORED          |
      CASELESS          |
      DOLLAR_ENDONLY    |
      DOTALL            |
      EXTENDED          |
      FIRSTLINE         |
      MULTILINE         |
      NEWLINE_ANY       |
      NEWLINE_ANYCRLF   |
      NEWLINE_CR        |
      NEWLINE_CRLF      |
      NEWLINE_LF        |
      NO_AUTO_CAPTURE   |
      NO_START_OPTIMIZE |
      NO_UTF_CHECK      |
      UNGREEDY          |
      UTF

const EXECUTE_MASK      =
      NEWLINE_ANY       |
      NEWLINE_ANYCRLF   |
      NEWLINE_CR        |
      NEWLINE_CRLF      |
      NEWLINE_LF        |
      NOTBOL            |
      NOTEMPTY          |
      NOTEMPTY_ATSTART  |
      NOTEOL            |
      NO_START_OPTIMIZE |
      NO_UTF_CHECK      |
      PARTIAL_HARD      |
      PARTIAL_SOFT


const OPTIONS_MASK = COMPILE_MASK | EXECUTE_MASK

const UNSET = ~Csize_t(0)  # Indicates that an output vector element is unset

function info(regex::Ptr{Void}, what::Integer, T)
    buf = zeros(UInt8,sizeof(T))
    ret = ccall((:pcre2_pattern_info_8, PCRE_LIB), Int32,
                (Ptr{Void}, Int32, Ptr{UInt8}),
                regex, what, buf)
    if ret != 0
        error(ret == ERROR_NULL      ? "NULL regex object" :
              ret == ERROR_BADMAGIC  ? "invalid regex object" :
              ret == ERROR_BADOPTION ? "invalid option flags" :
                                       "unknown error $ret")
    end
    reinterpret(T,buf)[1]
end

function get_ovec(match_data)
    ptr = ccall((:pcre2_get_ovector_pointer_8, PCRE_LIB), Ptr{Csize_t},
                (Ptr{Void},), match_data)
    n = ccall((:pcre2_get_ovector_count_8, PCRE_LIB), UInt32,
              (Ptr{Void},), match_data)
    pointer_to_array(ptr, 2n, false)
end

function compile(pattern::AbstractString, options::Integer)
    errno = Ref{Cint}(0)
    erroff = Ref{Csize_t}(0)
    re_ptr = ccall((:pcre2_compile_8, PCRE_LIB), Ptr{Void},
                   (Ptr{UInt8}, Csize_t, UInt32, Ref{Cint}, Ref{Csize_t}, Ptr{Void}),
                   pattern, sizeof(pattern), options, errno, erroff, C_NULL)
    re_ptr == C_NULL && error("PCRE compilation error: $(err_message(errno[])) at offset $(erroff[])")
    re_ptr
end

function jit_compile(regex::Ptr{Void})
    errno = ccall((:pcre2_jit_compile_8, PCRE_LIB), Cint,
                  (Ptr{Void}, UInt32), regex, JIT_COMPLETE)
    errno == 0 || error("PCRE JIT error: $(err_message(errno))")
end

free_match_data(match_data) =
    ccall((:pcre2_match_data_free_8, PCRE_LIB), Void, (Ptr{Void},), match_data)

free_re(re) =
    ccall((:pcre2_code_free_8, PCRE_LIB), Void, (Ptr{Void},), re)

free_jit_stack(stack) =
    ccall((:pcre2_jit_stack_free_8, PCRE_LIB), Void, (Ptr{Void},), stack)

free_match_context(context) =
    ccall((:pcre2_match_context_free_8, PCRE_LIB), Void, (Ptr{Void},), context)

function err_message(errno)
    buffer = Array(UInt8, 256)
    ccall((:pcre2_get_error_message_8, PCRE_LIB), Void,
          (Int32, Ptr{UInt8}, Csize_t), errno, buffer, sizeof(buffer))
    bytestring(pointer(buffer))
end

function exec(re,subject,offset,options,match_data)
    rc = ccall((:pcre2_match_8, PCRE_LIB), Cint,
               (Ptr{Void}, Ptr{UInt8}, Csize_t, Csize_t, Cuint, Ptr{Void}, Ptr{Void}),
               re, subject, sizeof(subject), offset, options, match_data, MATCH_CONTEXT)
    # rc == -1 means no match, -2 means partial match.
    rc < -2 && error("PCRE.exec error: $(err_message(rc))")
    rc >= 0
end

function create_match_data(re)
    ccall((:pcre2_match_data_create_from_pattern_8, PCRE_LIB),
          Ptr{Void}, (Ptr{Void}, Ptr{Void}), re, C_NULL)
end

function substring_number_from_name(re, name)
  ccall((:pcre2_substring_number_from_name_8, PCRE_LIB), Cint,
        (Ptr{Void}, Cstring), re, name)
end

function substring_length_bynumber(match_data, number)
    s = Ref{Csize_t}()
    rc = ccall((:pcre2_substring_length_bynumber_8, PCRE_LIB), Cint,
          (Ptr{Void}, UInt32, Ref{Csize_t}), match_data, number, s)
    rc < 0 && error("PCRE error: $(err_message(rc))")
    convert(Int, s[])
end

function substring_copy_bynumber(match_data, number, buf, buf_size)
    s = Ref{Csize_t}(buf_size)
    rc = ccall((:pcre2_substring_copy_bynumber_8, PCRE_LIB), Cint,
               (Ptr{Void}, UInt32, Ptr{UInt8}, Ref{Csize_t}),
               match_data, number, buf, s)
    rc < 0 && error("PCRE error: $(err_message(rc))")
    convert(Int, s[])
end

function capture_names(re)
    name_count = info(re, INFO_NAMECOUNT, UInt32)
    name_entry_size = info(re, INFO_NAMEENTRYSIZE, UInt32)
    nametable_ptr = info(re, INFO_NAMETABLE, Ptr{UInt8})
    names = Dict{Int, String}()
    for i=1:name_count
        offset = (i-1)*name_entry_size + 1
        # The capture group index corresponding to name 'i' is stored as a
        # big-endian 16-bit value.
        high_byte = UInt16(unsafe_load(nametable_ptr, offset))
        low_byte = UInt16(unsafe_load(nametable_ptr, offset+1))
        idx = (high_byte << 8) | low_byte
        # The capture group name is a null-terminated string located directly
        # after the index.
        names[idx] = bytestring(nametable_ptr+offset+1)
    end
    names
end

end # module
