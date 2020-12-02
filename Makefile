mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

# raw text input
RAWINPUT=tests/test_input/input.test
#RAWINPUT=tests/test_input/puzser.test
#
# some larger raw testfiles available on juniper...
#RAWINPUT=/store/projects/e-magyar/test_input/hundredthousandwords.txt

# input crafted directly for emTag
#TAGINPUT=tests/test_input/emTag.test

# input crafted directly for emDep
#DEPINPUT=tests/test_input/emDep.test

# ----------

all: usage

# always update according to targets below :)
usage:
	@echo
	@echo "You can..."
	@echo " make test-tok-morph"
	@echo " make test-tok-morph-tag"
	@echo " make test-tok-morph-tag-single"
	@echo " make test-tok-dep-single"
	@echo " make test-tok-chunk-ner-single"
	@echo " make test-tok-cons-single"
#	@echo " make test-tag"
#	@echo " make test-dep"
	@echo

# ----------

# testing emTok + emMorph (separately)
test-tok-morph:
	@cat $(RAWINPUT) \
     | python3 $(mkfile_dir)/main.py tok \
     | python3 $(mkfile_dir)/main.py morph

# testing emTok + emMorph + emTag (separately)
test-tok-morph-tag:
	@cat $(RAWINPUT) \
     | python3 $(mkfile_dir)/main.py tok \
     | python3 $(mkfile_dir)/main.py morph \
     | python3 $(mkfile_dir)/main.py pos

# testing emTok + emMorph + emTag
test-tok-morph-tag-single:
	@cat $(RAWINPUT) \
     | python3 $(mkfile_dir)/main.py tok,morph,pos

# testing emTok + emMorph + emTag + em_morph2UD + emDepUD
test-tok-dep-single:
	@cat $(RAWINPUT) \
     | python3 $(mkfile_dir)/main.py tok,morph,pos,conv-morph,dep

# testing emTok + emMorph + emTag + em_morph2UD + emDepUD + emChunk + emNer
# XXX currently without emCons
test-all-single:
	@cat $(RAWINPUT) \
     | python3 $(mkfile_dir)/main.py tok,morph,pos,conv-morph,dep,chunk,ner

# ----------

# testing emTok + emMorph + emTag + em_morph2UD + emDepUD + emCons
test-tok-cons-single:
	@cat $(RAWINPUT) \
     | python3 $(mkfile_dir)/main.py tok,morph,pos,conv-morph,dep,cons

# ----------

update_repo:
	@if [ "$$(git status --porcelain)" ] ; then \
		echo 'Working dir is dirty!' ; \
		exit 1 ; \
		fi
	@git pull && git submodule foreach git pull origin master
.PHONY: update_repo


# testing emTag only -- ezt majd!
#test-tag:
#	@cat $(TAGINPUT) \
#    | python3 $(mkfile_dir)/main.py pos

#	testing emDep only -- ezt majd!
#test-dep:
#	@cat $(DEPINPUT) \
#    | python3 $(mkfile_dir)/main.py dep


venv:
	# rm -rf venv
	# python3 -m venv venv
	venv/bin/pip install cython
	venv/bin/pip install -r requirements.txt
	for req in */requirements.txt ; do venv/bin/pip install -r $${req} ; done
.PHONY: venv

# ----------------------
# Docker related targets
# ----------------------

VERSION = $$(grep -E "__version__\s*=\s*'[^']+'" __init__.py | sed  -r "s/__version__ = '([^']+)'/\1/")

## build docker image
dbuild:
	docker build -t mtaril/emtsv:latest -t mtaril/emtsv:$(VERSION) .
.PHONY: dbuild


## build docker test image
dbuildtest:
	docker build -t mtaril/emtsv:test .
.PHONY: dbuildtest


## run docker container in background, without volume mapping
drun:
	@make -s dstop
	@myport=$$(./docker/freeportfinder.sh) ; \
		if [ -z "$${myport}" ] ; then echo 'ERROR: no free port' ; exit 1 ; fi ; \
		docker run --name emtsv -p $${myport}:5000 --rm -d mtaril/emtsv:latest ; \
		echo "OK: emtsv container run on port $${myport}" ;
.PHONY: drun


# connect emtsv container that is already running
dconnect:
	@if [ "$$(docker container ls -f name=emtsv -q)" ] ; then \
		docker exec -it emtsv /bin/sh ; \
	else \
		echo 'no running emtsv container' ; \
	fi
.PHONY: dconnect


# test the test image
dtest: # dbuildtest
	@./tests/dtest.sh
.PHONY: dtest



## stop running emtsv container
dstop:
	@if [ "$$(docker container ls -f name=emtsv -q)" ] ; then \
		docker container stop emtsv ; \
	else \
		echo 'no running emtsv container' ; \
	fi
.PHONY: dstop


## show images and containers
dls:
	@echo 'IMAGES:'
	@docker image ls
	@echo
	@echo 'CONTAINERS:'
	@docker container ls
.PHONY: dls


## delete unnecessary containers and images
dclean:
	@docker container prune -f
	@docker image prune -f
.PHONY: dclean
