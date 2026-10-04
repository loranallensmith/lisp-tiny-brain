(require :asdf)
(load "lisp-tiny-brain.asd")
(asdf:load-system :lisp-tiny-brain/tests)
(uiop:quit (if (tiny-brain/tests:run-tests) 0 1))
