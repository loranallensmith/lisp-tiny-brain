(in-package #:tiny-brain)

(defstruct (world
            (:constructor %make-world))
  facts)

(defstruct (agent
            (:constructor %make-agent))
  (beliefs nil)
  (unknowns nil)
  (clock 0))

(defstruct belief
  fact
  confidence
  source
  observed-at
  rule
  premises)

(defstruct rule
  name
  premises
  conclusion)

(defun make-world ()
  "Create the tiny ground-truth environment.

The world contains facts the agent may not inspect directly through the public
API. Observations expose selected facts to the agent."
  (%make-world
   :facts '((room room-1)
            (room room-2)
            (object ball-1)
            (color ball-1 red)
            (shape ball-1 sphere)
            (size ball-1 small)
            (location ball-1 room-1)
            (container box-1)
            (closed box-1)
            (color box-1 blue)
            (location box-1 room-1)
            (object key-1)
            (color key-1 brass)
            (location key-1 box-1))))

(defun make-agent ()
  "Create an agent with no initial beliefs."
  (%make-agent))

(defun fact-predicate (fact)
  (first fact))

(defun fact-subject (fact)
  (second fact))

(defun fact-object (fact)
  (third fact))

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

(defun fact= (left right)
  (term= left right))

(defun add-belief (agent fact &key
                                (confidence 1.0)
                                (source :direct-observation)
                                rule
                                premises)
  "Record FACT as a belief unless the agent already believes it."
  (unless (find fact (agent-beliefs agent) :key #'belief-fact :test #'fact=)
    (incf (agent-clock agent))
    (push (make-belief :fact fact
                       :confidence confidence
                       :source source
                       :observed-at (agent-clock agent)
                       :rule rule
                       :premises premises)
          (agent-beliefs agent)))
  fact)

(defun add-unknown (agent unknown)
  "Record an explicit unknown unless it is already present."
  (pushnew unknown (agent-unknowns agent) :test #'term=)
  unknown)

(defun facts-matching (world predicate &key subject object)
  (remove-if-not
   (lambda (fact)
     (and (symbol-name= (fact-predicate fact) predicate)
          (or (null subject) (term= (fact-subject fact) subject))
          (or (null object) (term= (fact-object fact) object))))
   (world-facts world)))

(defun fact-present-p (world fact)
  (find fact (world-facts world) :test #'fact=))

(defun observable-properties-for (world thing)
  "Return simple properties visible from looking at THING.

This is intentionally small and concrete for v0.1. A future observation model
should make visibility rules explicit rather than burying them in this helper."
  (remove-if-not
   (lambda (fact)
     (and (term= (fact-subject fact) thing)
          (member (fact-predicate fact)
                  '(object container color shape size location closed)
                  :test #'symbol-name=)))
   (world-facts world)))

(defun things-located-in (world place)
  (mapcar #'fact-subject
          (facts-matching world 'location :object place)))

(defun observe-room (agent world room)
  (add-belief agent `(room ,room))
  (dolist (thing (things-located-in world room))
    (dolist (fact (observable-properties-for world thing))
      (add-belief agent fact))
    (when (fact-present-p world `(closed ,thing))
      (add-unknown agent `(contents ,thing))))
  agent)

(defun observe (agent world target)
  "Let AGENT observe TARGET in WORLD.

The agent learns only through observations. This function is the controlled
boundary where selected ground-truth facts become beliefs."
  (cond
    ((fact-present-p world `(room ,target))
     (observe-room agent world target))
    (t
     (error "Don't know how to observe ~S yet." target))))

(defparameter *default-rules*
  (list
   (make-rule :name :thing-in-observed-room-is-visible
              :premises '((location ?thing ?room)
                          (room ?room))
              :conclusion '(visible ?thing))
   (make-rule :name :container-is-object
              :premises '((container ?thing))
              :conclusion '(object ?thing))
   (make-rule :name :location-through-container
              :premises '((location ?thing ?container)
                          (location ?container ?place))
              :conclusion '(location ?thing ?place))))

(defun variable-symbol-p (term)
  (and (symbolp term)
       (plusp (length (symbol-name term)))
       (char= (char (symbol-name term) 0) #\?)))

(defun binding-for (variable bindings)
  (assoc variable bindings :test #'symbol-name=))

(defparameter *match-failed* (gensym "MATCH-FAILED-"))

(defun match-failed-p (value)
  (eq value *match-failed*))

(defun bind-variable (variable value bindings)
  (let ((existing (binding-for variable bindings)))
    (cond
      ((null existing)
       (acons variable value bindings))
      ((term= (cdr existing) value)
       bindings)
      (t
       *match-failed*))))

(defun match-pattern (pattern fact &optional bindings)
  "Return updated bindings if PATTERN matches FACT, otherwise NIL."
  (cond
    ((variable-symbol-p pattern)
     (bind-variable pattern fact bindings))
    ((and (consp pattern) (consp fact))
     (let ((head-bindings (match-pattern (first pattern) (first fact) bindings)))
       (if (match-failed-p head-bindings)
           *match-failed*
           (match-pattern (rest pattern) (rest fact) head-bindings))))
    ((or (consp pattern) (consp fact))
     *match-failed*)
    ((term= pattern fact)
     bindings)
    (t
     *match-failed*)))

(defun instantiate (pattern bindings)
  (cond
    ((variable-symbol-p pattern)
     (let ((binding (binding-for pattern bindings)))
       (if binding
           (cdr binding)
           pattern)))
    ((consp pattern)
     (cons (instantiate (first pattern) bindings)
           (instantiate (rest pattern) bindings)))
    (t
     pattern)))

(defun matching-beliefs (agent premise bindings)
  (loop for belief in (agent-beliefs agent)
        for new-bindings = (match-pattern premise (belief-fact belief) bindings)
        unless (match-failed-p new-bindings)
          collect (cons belief new-bindings)))

(defun premise-matches (agent premises &optional bindings matched-beliefs)
  (if (null premises)
      (list (cons (reverse matched-beliefs) bindings))
      (loop for match in (matching-beliefs agent (first premises) bindings)
            append (premise-matches agent
                                    (rest premises)
                                    (cdr match)
                                    (cons (car match) matched-beliefs)))))

(defun infer-from-rule (agent rule)
  (let ((new-facts nil))
    (dolist (match (premise-matches agent (rule-premises rule)))
      (let* ((premise-beliefs (car match))
             (bindings (cdr match))
             (fact (instantiate (rule-conclusion rule) bindings))
             (confidence (reduce #'min premise-beliefs
                                 :key #'belief-confidence
                                 :initial-value 1.0)))
        (unless (why agent fact)
          (add-belief agent fact
                      :confidence confidence
                      :source :inference
                      :rule (rule-name rule)
                      :premises (mapcar #'belief-fact premise-beliefs))
          (push fact new-facts))))
    new-facts))

(defun infer (agent &optional (rules *default-rules*))
  "Derive new beliefs from AGENT's current beliefs using RULES.

This is forward chaining over explicit beliefs only. It never inspects the
world's ground truth."
  (loop
    for new-facts = (loop for rule in rules append (infer-from-rule agent rule))
    while new-facts
    append new-facts into all-new-facts
    finally (return all-new-facts)))

(defun why (agent fact)
  "Return the belief record explaining why AGENT believes FACT, or NIL."
  (find fact (agent-beliefs agent) :key #'belief-fact :test #'fact=))

(defun sorted-copy (items key)
  (sort (copy-list items) #'string<
        :key (lambda (item)
               (prin1-to-string (funcall key item)))))

(defun show-beliefs (agent &optional (stream *standard-output*))
  "Print AGENT's known beliefs and explicit unknowns."
  (format stream "~&KNOWN:~%")
  (dolist (belief (sorted-copy (agent-beliefs agent) #'belief-fact))
    (format stream "  ~S~%" (belief-fact belief)))
  (format stream "~&UNKNOWN:~%")
  (dolist (unknown (sorted-copy (agent-unknowns agent) #'identity))
    (format stream "  ~S~%" unknown))
  (values))
