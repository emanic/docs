
RESULT := $(shell (docker run --rm -v "$(PWD):/workdir" tmaier/hunspell -u3 -d en_US -p our_dict -H admin_guide/access_control/*.adoc))

test:
	@echo "$(RESULT)"
	@if [ "$(RESULT)" != "" ]; then\
        exit 1;\
    fi
