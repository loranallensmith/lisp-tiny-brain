(require :asdf)
(load "lisp-tiny-brain.asd")
(asdf:load-system :lisp-tiny-brain)

(defpackage #:tiny-brain/validator
  (:use #:cl #:tiny-brain))

(in-package #:tiny-brain/validator)

(defun usage (&optional (stream *error-output*))
  (format stream "~&Usage: sbcl --script scripts/validate-scenario.lisp SCENARIO~%")
  (format stream "~&Example: sbcl --script scripts/validate-scenario.lisp examples/kitchen-box.lisp~%"))

(defun validation-errors-p (issues)
  (find :error issues :key #'validation-issue-severity))

(defun validate-scenario-file (pathname)
  (let ((scenario (load-scenario pathname))
        (*package* (find-package '#:tiny-brain)))
    (format t "~&SCENARIO: ~S~%" (scenario-name scenario))
    (format t "FILE: ~A~%" pathname)
    (let ((issues (validate-scenario scenario)))
      (show-validation issues)
      (unless (validation-errors-p issues)
        (format t "~&Scenario is ready to run.~%"))
      (validation-errors-p issues))))

(defun main ()
  (let ((args (uiop:command-line-arguments)))
    (handler-case
        (cond
          ((null args)
           (usage)
           (uiop:quit 2))
          ((validate-scenario-file (first args))
           (uiop:quit 1))
          (t
           (uiop:quit 0)))
      (error (condition)
        (format *error-output* "~&Error: ~A~%" condition)
        (usage)
        (uiop:quit 1)))))

(main)
