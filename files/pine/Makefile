.PHONY: repl dev check

GUIX := guix shell -m manifest.scm --
ENV  := LD_LIBRARY_PATH="$$GUIX_ENVIRONMENT/lib" ASDF_OUTPUT_TRANSLATIONS="/:$$HOME/.cache/common-lisp/pine/"

repl:
	$(GUIX) sh -c '$(ENV) sbcl --eval "(asdf:load-system :pine)"'

dev:
	$(GUIX) sh -c '$(ENV) LD_PRELOAD="$$GUIX_ENVIRONMENT/lib/libgtk4-layer-shell.so" sbcl --eval "(asdf:load-system :pine/gtk)" --eval "(pine.gtk:run)"'

check:
	$(GUIX) sh -c '$(ENV) sbcl --non-interactive --eval "(asdf:load-system :pine/gtk)" --eval "(princ :loaded)" --eval "(terpri)"'
