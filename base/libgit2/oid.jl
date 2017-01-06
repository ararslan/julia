# This file is a part of Julia. License is MIT: http://julialang.org/license

function _githash(h::String)
    len = length(h)
    if len == OID_HEXSZ
        return GitHash(h)
    elseif len < OID_HEXSZ
        return GitShortHash(GitHash(h), len)
    else
        error("string \"$h\" is too long to be a Git hash")
    end
end

"""
    @githash_str

Construct a `GitHash` or `GitShortHash` depending on the length of the provided string.
"""
macro githash_str(h)
    :(_githash($h))
end

GitHash(id::GitHash) = id
GitHash(ptr::Ptr{GitHash}) = unsafe_load(ptr)::GitHash

function GitHash(id::GitShortHash)
    if id.len < OID_RAWSZ
        throw(ArgumentError("cannot convert a GitShortHash with length < $OID_RAWSZ to a full GitHash"))
    end
    return id.hash
end

GitShortHash(id::GitShortHash) = id
GitShortHash(id::GitHash) = GitShortHash(id, OID_RAWSZ)
GitShortHash(ptr::Ptr{GitHash}) = GitShortHash(unsafe_load(ptr)::GitHash)

function GitHash(ptr::Ptr{UInt8})
    if ptr == C_NULL
        throw(ArgumentError("NULL pointer passed to GitHash() constructor"))
    end
    oid_ptr = Ref(GitHash())
    ccall((:git_oid_fromraw, :libgit2), Void, (Ptr{GitHash}, Ptr{UInt8}), oid_ptr, ptr)
    return oid_ptr[]
end

GitShortHash(ptr::Ptr{UInt8}) = GitShortHash(GitHash(ptr))

function GitHash(id::Array{UInt8,1})
    if length(id) != OID_RAWSZ
        throw(ArgumentError("invalid raw buffer size"))
    end
    return GitHash(pointer(id))
end

GitShortHash(id::Array{UInt8,1}) = GitShortHash(GitHash(id))

function GitHash(id::AbstractString)
    bstr = String(id)
    len = sizeof(bstr)
    len == OID_RAWSZ || throw(ArgumentError("expected a string of length $OID_RAWSZ, got $len"))
    oid_ptr = Ref(GitHash())
    err = ccall((:git_oid_fromstrp, :libgit2), Cint,
                (Ptr{GitHash}, Cstring), oid_ptr, bstr)
    err == 0 || return GitHash()
    return oid_ptr[]
end

function GitShortHash(id::AbstractString)
    bstr = String(id)
    len = sizeof(bstr)
    oid_ptr = Ref(GitHash())
    err = ccall((:git_oid_fromstrn, :libgit2), Cint,
                (Ptr{GitHash}, Ptr{UInt8}, Csize_t), oid_ptr, bstr, len)
    err == 0 || return GitShortHash(GitHash())
    return GitShortHash(oid_ptr[], len)
end

function GitHash(ref::GitReference)
    isempty(ref) && return GitHash()
    reftype(ref) != Consts.REF_OID && return GitHash()
    oid_ptr = ccall((:git_reference_target, :libgit2), Ptr{UInt8}, (Ptr{Void},), ref.ptr)
    oid_ptr == C_NULL && return GitHash()
    return GitHash(oid_ptr)
end

GitShortHash(ref::GitReference) = GitShortHash(GitHash(ref))

function GitHash(repo::GitRepo, ref_name::AbstractString)
    isempty(repo) && return GitHash()
    oid_ptr  = Ref(GitHash())
    @check ccall((:git_reference_name_to_id, :libgit2), Cint,
                    (Ptr{GitHash}, Ptr{Void}, Cstring),
                     oid_ptr, repo.ptr, ref_name)
    return oid_ptr[]
end

GitShortHash(repo::GitRepo, ref_name::AbstractString) = GitShortHash(GitHash(repo, ref_name))

function GitHash(obj::Ptr{Void})
    oid_ptr = ccall((:git_object_id, :libgit2), Ptr{UInt8}, (Ptr{Void},), obj)
    oid_ptr == C_NULL && return GitHash()
    return GitHash(oid_ptr)
end

GitShortHash(obj::Ptr{Void}) = GitShortHash(GitHash(obj))

function GitHash{T<:GitObject}(obj::T)
    obj === nothing && return GitHash()
    return GitHash(obj.ptr)
end

GitShortHash(obj::GitObject) = GitShortHash(GitHash(obj))

Base.hex(id::GitHash) = join([hex(i,2) for i in id.val])
Base.hex(id::GitShortHash) = join([hex(i,2) for i in id.hash.val[1:id.len]])

raw(id::GitHash) = collect(id.val)
raw(id::GitShortHash) = collect(id.hash.val[1:len])

Base.string(id::GitHash) = hex(id)
Base.string(id::GitShortHash) = hex(id.hash)

Base.show(io::IO, id::GitHash) = print(io, "GitHash($(string(id)))")
Base.show(io::IO, id::GitShortHash) = print(io, "GitShortHash($(string(id)[1:id.len]))")

Base.hash(id::GitHash, h::UInt) = hash(id.val, h)
Base.hash(id::GitShortHash, h::UInt) = hash(id.hash, h)

cmp(id1::GitHash, id2::GitHash) = Int(ccall((:git_oid_cmp, :libgit2), Cint,
                                    (Ptr{GitHash}, Ptr{GitHash}), Ref(id1), Ref(id2)))
cmp(id1::GitShortHash, id2::GitShortHash) = cmp(id1.hash, id2.hash)

==(id1::GitHash, id2::GitHash) = cmp(id1, id2) == 0
==(id1::GitShortHash, id2::GitShortHash) = cmp(id1, id2) == 0

Base.isless(id1::GitHash, id2::GitHash) = cmp(id1, id2) < 0
Base.isless(id1::GitShortHash, id2::GitShortHash) = cmp(id1, id2) < 0

function iszero(id::GitHash)
    for i in 1:OID_RAWSZ
        id.val[i] != zero(UInt8) && return false
    end
    return true
end

iszero(id::GitShortHash) = iszero(id.hash)

Base.zero(::Type{GitHash}) = GitHash()
Base.zero(::Type{GitShortHash}) = GitShortHash(GitHash())
