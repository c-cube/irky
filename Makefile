DUNE_OPTS?=

all:
	@dune build @install $(DUNE_OPTS)

doc:
	@dune build @doc $(DUNE_OPTS)

clean:
	@dune clean

test:
	@dune runtest --force $(DUNE_OPTS) 

WATCH?=@check
watch:
	@dune build $(DUNE_OPTS) $(WATCH) --watch

