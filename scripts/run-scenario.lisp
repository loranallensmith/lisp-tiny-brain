(require :asdf)
(load "lisp-tiny-brain.asd")
(asdf:load-system :lisp-tiny-brain)

(defpackage #:tiny-brain/runner
  (:use #:cl #:tiny-brain))

(in-package #:tiny-brain/runner)

(defparameter *default-step-limit* 3)

(defun usage (&optional (stream *error-output*))
  (format stream "~&Usage: sbcl --script scripts/run-scenario.lisp SCENARIO [STEPS] [--cognitive]~%")
  (format stream "~&Example: sbcl --script scripts/run-scenario.lisp examples/kitchen-box.lisp~%")
  (format stream "~&Example: sbcl --script scripts/run-scenario.lisp examples/kitchen-box.lisp --cognitive~%"))

(defun cognitive-flag-p (text)
  (string= text "--cognitive"))

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

(defun parse-run-options (args)
  (let ((steps *default-step-limit*)
        (cognitive nil))
    (dolist (arg args)
      (cond
        ((cognitive-flag-p arg)
         (setf cognitive t))
        ((digit-char-p (char arg 0))
         (setf steps (parse-step-limit arg)))
        (t
         (error "Unknown option: ~A" arg))))
    (values steps cognitive)))

(defun run-scenario-file (pathname &key (steps *default-step-limit*) cognitive)
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
          (when cognitive
            (show-heading (format nil "COGNITIVE CYCLE ~D" (1+ index)))
            (show-cognition agent trace))
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
           (multiple-value-bind (steps cognitive)
               (parse-run-options (rest args))
             (run-scenario-file (first args)
                                :steps steps
                                :cognitive cognitive))))
      (error (condition)
        (format *error-output* "~&Error: ~A~%" condition)
        (usage)
        (uiop:quit 1)))))

(main)
