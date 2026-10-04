(require :asdf)
(load "lisp-tiny-brain.asd")
(asdf:load-system :lisp-tiny-brain)

(defpackage #:tiny-brain/runner
  (:use #:cl #:tiny-brain))

(in-package #:tiny-brain/runner)

(defparameter *default-step-limit* 3)

(defun usage (&optional (stream *error-output*))
  (format stream "~&Usage: sbcl --script scripts/run-scenario.lisp SCENARIO [STEPS]~%")
  (format stream "~&Example: sbcl --script scripts/run-scenario.lisp examples/kitchen-box.lisp~%"))

(defun parse-step-limit (text)
  (let ((value (parse-integer text :junk-allowed t)))
    (if (and value (plusp value))
        value
        (error "Step count must be a positive integer: ~S" text))))

(defun terminal-step-p (trace)
  (member (step-trace-status trace) '(:satisfied :blocked :idle)))

(defun validation-errors-p (issues)
  (find :error issues :key #'validation-issue-severity))

(defun show-heading (text)
  (format t "~&~%~A~%" text)
  (format t "~A~%" (make-string (length text) :initial-element #\-)))

(defun run-scenario-file (pathname &key (steps *default-step-limit*))
  (let ((scenario (load-scenario pathname))
        (*package* (find-package '#:tiny-brain)))
    (let ((issues (validate-scenario scenario)))
      (when issues
        (show-validation issues *error-output*))
      (when (validation-errors-p issues)
        (uiop:quit 1)))
    (multiple-value-bind (agent world)
        (start-scenario scenario)
      (format t "~&SCENARIO: ~S~%" (scenario-name scenario))
      (format t "FILE: ~A~%" pathname)
      (show-heading "INITIAL MEMORY")
      (show-memory agent)
      (dotimes (index steps)
        (let ((trace (step-agent agent world)))
          (show-heading (format nil "STEP ~D" (1+ index)))
          (show-trace trace)
          (when (terminal-step-p trace)
            (return))))
      (show-heading "FINAL MEMORY")
      (show-memory agent))))

(defun main ()
  (let ((args (uiop:command-line-arguments)))
    (handler-case
        (cond
          ((null args)
           (usage)
           (uiop:quit 2))
          (t
           (run-scenario-file (first args)
                              :steps (if (second args)
                                         (parse-step-limit (second args))
                                         *default-step-limit*))))
      (error (condition)
        (format *error-output* "~&Error: ~A~%" condition)
        (usage)
        (uiop:quit 1)))))

(main)
