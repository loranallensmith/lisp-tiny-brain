(asdf:defsystem #:lisp-tiny-brain
  :description "A tiny inspectable artificial mind experiment."
  :author "Allen and Codex"
  :license "UNLICENSED"
  :serial t
  :components ((:file "src/package")
               (:file "src/core"))
  :in-order-to ((asdf:test-op (asdf:test-op #:lisp-tiny-brain/tests))))

(asdf:defsystem #:lisp-tiny-brain/tests
  :description "Tests for lisp-tiny-brain."
  :depends-on (#:lisp-tiny-brain)
  :serial t
  :components ((:file "tests/package")
               (:file "tests/core-tests"))
  :perform (asdf:test-op (operation system)
             (declare (ignore operation system))
             (uiop:symbol-call :tiny-brain/tests :run-tests)))

