(in-package #:tiny-brain/tests)

(defvar *failures* 0)

(defmacro check (form)
  `(unless ,form
     (incf *failures*)
     (format t "~&FAIL: ~S~%" ',form)))

(defun symbol-name= (left right)
  (and (symbolp left)
       (symbolp right)
       (string= (symbol-name left) (symbol-name right))))

(defun term= (left right)
  (cond
    ((and (consp left) (consp right))
     (and (term= (first left) (first right))
          (term= (rest left) (rest right))))
    ((or (consp left) (consp right))
     nil)
    ((and (symbolp left) (symbolp right))
     (symbol-name= left right))
    (t
     (eql left right))))

(defun test-observing-room-adds-visible-beliefs ()
  (let ((world (make-world))
        (agent (make-agent)))
    (observe agent world 'room-1)
    (check (why agent '(room room-1)))
    (check (why agent '(object ball-1)))
    (check (why agent '(color ball-1 red)))
    (check (why agent '(location ball-1 room-1)))))

(defun test-observing-room-does-not-reveal-closed-container-contents ()
  (let ((world (make-world))
        (agent (make-agent)))
    (observe agent world 'room-1)
    (check (why agent '(container box-1)))
    (check (member '(contents box-1) (agent-unknowns agent) :test #'term=))
    (check (not (why agent '(object key-1))))
    (check (not (why agent '(location key-1 box-1))))))

(defun test-beliefs-have-provenance ()
  (let ((world (make-world))
        (agent (make-agent)))
    (observe agent world 'room-1)
    (let ((belief (why agent '(color ball-1 red))))
      (check belief)
      (check (eql (belief-source belief) :direct-observation))
      (check (= (belief-confidence belief) 1.0))
      (check (integerp (belief-observed-at belief))))))

(defun run-tests ()
  (setf *failures* 0)
  (test-observing-room-adds-visible-beliefs)
  (test-observing-room-does-not-reveal-closed-container-contents)
  (test-beliefs-have-provenance)
  (if (zerop *failures*)
      (progn
        (format t "~&All tests passed.~%")
        t)
      (progn
        (format t "~&~D test failure~:P.~%" *failures*)
        (uiop:quit 1))))
