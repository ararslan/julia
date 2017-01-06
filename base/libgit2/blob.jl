# This file is a part of Julia. License is MIT: http://julialang.org/license

function content(blob::GitBlob)
    return ccall((:git_blob_rawcontent, :libgit2), Ptr{Void}, (Ptr{Void},), blob.ptr)
end

function Base.length(blob::GitBlob)
    return ccall((:git_blob_rawsize, :libgit2), Int64, (Ptr{Void},), blob.ptr)
end

"""
    lookup(repo::GitRepo, oid::AbstractGitHash)

Look up the Git blob corresponding to the hash `oid` within the given repository.
"""
function lookup(repo::GitRepo, oid::GitHash)
    blob_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_blob_lookup, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}, Ref{GitHash}),
                   blob_ptr_ptr, repo.ptr, Ref(oid))
    return GitBlob(blob_ptr_ptr[])
end

function lookup(repo::GitRepo, oid::GitShortHash)
    blob_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    @check ccall((:git_blob_lookup_prefix, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ref{GitHash}),
                 blob_ptr_ptr, repo.ptr, Ref(oid.hash), oid.len)
    return GitBlob(blob_ptr_ptr[])
end
