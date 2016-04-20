# This file is a part of Julia. License is MIT: http://julialang.org/license


"""
    pgenerate([::WorkerPool], f, c...) -> iterator

Apply `f` to each element of `c` in parallel using available workers and tasks.

For multiple collection arguments, apply f elementwise.

Results are returned in order as they become available.

Note that `f` must be made available to all worker processes; see
[Code Availability and Loading Packages](:ref:`Code Availability
and Loading Packages <man-parallel-computing-code-availability>`)
for details.
"""
function pgenerate(p::WorkerPool, f, c; config=DEFAULT_PMAP_ARGS)
    batch_size = config[:batch_size]
    on_error = config[:on_error]
    distributed = config[:distributed]

    if  (distributed == false) ||
        (length(p) == 0) ||
        (length(p) == 1 && fetch(p.channel) == myid())

        return AsyncGenerator(f, c; on_error=on_error)
    end

    if batch_size == :auto
        batches = batchsplit(c, min_batch_count = length(p) * 3)
    else
        batches = batchsplit(c, max_batch_size = batch_size)
    end
    return flatten(AsyncGenerator(remote(p, b -> asyncmap(f, b; on_error=on_error)), batches; on_error=on_error))
end

pgenerate(p::WorkerPool, f, c1, c...; kwargs...) = pgenerate(p, a->f(a...), zip(c1, c...); kwargs...)

pgenerate(f, c; kwargs...) = pgenerate(default_worker_pool(), f, c...; kwargs...)
pgenerate(f, c1, c...; kwargs...) = pgenerate(a->f(a...), zip(c1, c...); kwargs...)


"""
    pmap([::WorkerPool], f, c...; distributed=true, batch_size=1, on_error=nothing) -> collection

Transform collection `c` by applying `f` to each element using available
workers and tasks.

For multiple collection arguments, apply f elementwise.

Note that `f` must be made available to all worker processes; see
[Code Availability and Loading Packages](:ref:`Code Availability
and Loading Packages <man-parallel-computing-code-availability>`)
for details.

If a worker pool is not specified, all available workers, i.e., the default worker pool
is used.

By default, `pmap` distributes the computation over all specified workers. To use only the
local process and distribute over tasks, specifiy `distributed=false`

`pmap` can also use a mix of processes and tasks via the `batch_size` argument. For batch sizes
greater than 1, the collection is split into multiple batches, which are distributed across
workers. Each such batch is processed in parallel via tasks in each worker. `batch_size=:auto`
will automtically calculate a batch size depending on the length of the collection and number
of workers available.

Any error stops pmap from processing the remainder of the collection. To override this behavior
you can specify an error handling function via argument `on_error` which takes in a single argument, i.e.,
the exception. The function can stop the processing by rethrowing the error, or, to continue, return any value
which is then returned inline with the results to the caller.
"""
function pmap(p::WorkerPool, f, c...; kwargs...)
    kwdict = merge(DEFAULT_PMAP_ARGS, AnyDict(kwargs))
    validate_pmap_kwargs(kwdict, PMAP_KW_NAMES)

    collect(pgenerate(p, f, c...; config=kwdict))
end


const DEFAULT_PMAP_ARGS = AnyDict(
    :distributed => true,
    :batch_size  => 1,
    :on_error  => nothing)

const PMAP_KW_NAMES = [:distributed, :batch_size, :on_error]
function validate_pmap_kwargs(kwdict, kwnames)
    unsupported = filter(x -> !(x in kwnames), collect(keys(kwdict)))
    length(unsupported) > 1 && throw(ArgumentError("keyword arguments $unsupported are not supported."))
    nothing
end


"""
    batchsplit(c; min_batch_count=1, max_batch_size=100) -> iterator

Split a collection into at least `min_batch_count` batches.

Equivalent to `partition(c, max_batch_size)` when `length(c) >> max_batch_size`.
"""
function batchsplit(c; min_batch_count=1, max_batch_size=100)
    if min_batch_count < 1
        throw(ArgumentError("min_batch_count must be ≥ 1, got $min_batch_count"))
    end

    if max_batch_size < 1
        throw(ArgumentError("max_batch_size must be ≥ 1, got $max_batch_size"))
    end

    # Split collection into batches, then peek at the first few batches
    batches = partition(c, max_batch_size)
    head, tail = head_and_tail(batches, min_batch_count)

    # If there are not enough batches, use a smaller batch size
    if length(head) < min_batch_count
        batch_size = max(1, div(sum(length, head), min_batch_count))
        return partition(collect(flatten(head)), batch_size)
    end

    return flatten((head, tail))
end
