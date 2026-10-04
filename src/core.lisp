(in-package #:tiny-brain)

(defstruct (world
            (:constructor %make-world))
  facts)

(defstruct (agent
            (:constructor %make-agent))
  (beliefs nil)
  (unknowns nil)
  (retractions nil)
  (goals nil)
  (episodes nil)
  (hypotheses nil)
  (clock 0))

(defstruct belief
  fact
  confidence
  source
  observed-at
  rule
  premises)

(defstruct retraction
  fact
  reason
  replaced-by
  retracted-at)

(defstruct rule
  name
  premises
  conclusion)

(defstruct action-suggestion
  action
  target
  reason
  preconditions
  serves-goal
  tests-question)

(defstruct selected-action
  suggestion
  reason)

(defstruct episode
  type
  detail
  results
  time)

(defstruct hypothesis
  question
  proposition
  confidence
  source
  status
  created-at
  resolved-at)

(defstruct goal
  desire
  status
  created-at
  satisfied-at)

(defstruct explanation
  fact
  status
  source
  confidence
  rule
  premises
  retraction)

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

(defparameter *exclusive-state-groups*
  '((open closed)))

(defun predicate-in-exclusive-group (predicate)
  (find-if (lambda (group)
             (member predicate group :test #'symbol-name=))
           *exclusive-state-groups*))

(defun exclusive-state-conflict-p (new-fact existing-fact)
  (let ((group (predicate-in-exclusive-group (fact-predicate new-fact))))
    (and group
         (= (length new-fact) 2)
         (= (length existing-fact) 2)
         (term= (fact-subject new-fact) (fact-subject existing-fact))
         (not (symbol-name= (fact-predicate new-fact)
                            (fact-predicate existing-fact)))
         (member (fact-predicate existing-fact) group :test #'symbol-name=))))

(defun conflicting-beliefs (agent fact)
  (remove-if-not (lambda (belief)
                   (exclusive-state-conflict-p fact (belief-fact belief)))
                 (agent-beliefs agent)))

(defun record-retraction (agent fact reason replaced-by)
  (incf (agent-clock agent))
  (push (make-retraction :fact fact
                         :reason reason
                         :replaced-by replaced-by
                         :retracted-at (agent-clock agent))
        (agent-retractions agent))
  fact)

(defun retract-belief (agent fact &key (reason :retracted) replaced-by)
  (when (find fact (agent-beliefs agent) :key #'belief-fact :test #'fact=)
    (setf (agent-beliefs agent)
          (remove fact (agent-beliefs agent) :key #'belief-fact :test #'fact=))
    (record-retraction agent fact reason replaced-by))
  fact)

(defun retract-conflicts-for (agent fact)
  (dolist (belief (conflicting-beliefs agent fact))
    (retract-belief agent
                    (belief-fact belief)
                    :reason :replaced-by-exclusive-state
                    :replaced-by fact)))

(defun add-belief (agent fact &key
                                (confidence 1.0)
                                (source :direct-observation)
                                rule
                                premises)
  "Record FACT as a belief unless the agent already believes it."
  (unless (find fact (agent-beliefs agent) :key #'belief-fact :test #'fact=)
    (retract-conflicts-for agent fact)
    (incf (agent-clock agent))
    (push (make-belief :fact fact
                       :confidence confidence
                       :source source
                       :observed-at (agent-clock agent)
                       :rule rule
                       :premises premises)
          (agent-beliefs agent)))
  (update-goals agent)
  (update-hypotheses agent)
  fact)

(defun remove-belief (agent fact)
  (retract-belief agent fact))

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

(defun remove-world-fact (world fact)
  (setf (world-facts world)
        (remove fact (world-facts world) :test #'fact=))
  fact)

(defun add-world-fact (world fact)
  (pushnew fact (world-facts world) :test #'fact=)
  fact)

(defun belief-facts (agent)
  (mapcar #'belief-fact (agent-beliefs agent)))

(defun new-facts-since (agent earlier-facts)
  (remove-if (lambda (fact)
               (member fact earlier-facts :test #'fact=))
             (belief-facts agent)))

(defun record-episode (agent type detail results)
  (incf (agent-clock agent))
  (push (make-episode :type type
                      :detail detail
                      :results results
                      :time (agent-clock agent))
        (agent-episodes agent))
  results)

(defun remove-unknown (agent unknown)
  (setf (agent-unknowns agent)
        (remove unknown (agent-unknowns agent) :test #'term=))
  (update-goals agent)
  unknown)

(defun contents-known-p (agent container)
  (and (not (member `(contents ,container) (agent-unknowns agent) :test #'term=))
       (or (why agent `(open ,container))
           (some (lambda (belief)
                   (and (symbol-name= (fact-predicate (belief-fact belief))
                                      'location)
                        (term= (fact-object (belief-fact belief)) container)))
                 (agent-beliefs agent)))))

(defun goal-satisfied-p (agent desire)
  (cond
    ((and (consp desire)
          (symbol-name= (first desire) 'known)
          (= (length desire) 2))
     (let ((target (second desire)))
       (cond
         ((and (consp target)
               (symbol-name= (fact-predicate target) 'contents)
               (fact-subject target))
          (contents-known-p agent (fact-subject target)))
         (t
          (why agent target)))))
    (t
     (why agent desire))))

(defun refresh-goal-status (agent goal)
  (cond
    ((goal-satisfied-p agent (goal-desire goal))
     (unless (eql (goal-status goal) :satisfied)
       (incf (agent-clock agent))
       (setf (goal-status goal) :satisfied
             (goal-satisfied-at goal) (agent-clock agent))))
    (t
     (setf (goal-status goal) :active
           (goal-satisfied-at goal) nil)))
  goal)

(defun update-goals (agent)
  "Refresh goal status from AGENT's current beliefs and unknowns."
  (dolist (goal (agent-goals agent))
    (refresh-goal-status agent goal))
  (agent-goals agent))

(defun add-goal (agent desire)
  "Add DESIRE as an explicit goal and return the goal record."
  (or (find desire (agent-goals agent) :key #'goal-desire :test #'term=)
      (progn
        (incf (agent-clock agent))
        (let ((goal (make-goal :desire desire
                               :status :active
                               :created-at (agent-clock agent))))
          (push goal (agent-goals agent))
          (refresh-goal-status agent goal)))))

(defun remove-goal (agent desire)
  "Remove the goal whose desire is DESIRE."
  (setf (agent-goals agent)
        (remove desire (agent-goals agent) :key #'goal-desire :test #'term=))
  desire)

(defun add-hypothesis (agent question proposition confidence
                       &key (source :manual))
  "Add a competing hypothesis for QUESTION."
  (or (find-if (lambda (hypothesis)
                 (and (term= (hypothesis-question hypothesis) question)
                      (term= (hypothesis-proposition hypothesis) proposition)))
               (agent-hypotheses agent))
      (progn
        (incf (agent-clock agent))
        (let ((hypothesis (make-hypothesis
                           :question question
                           :proposition proposition
                           :confidence confidence
                           :source source
                           :status :active
                           :created-at (agent-clock agent))))
          (push hypothesis (agent-hypotheses agent))
          (refresh-hypothesis-status agent hypothesis)))))

(defun contents-question-p (question)
  (and (consp question)
       (symbol-name= (fact-predicate question) 'contents)
       (fact-subject question)
       (= (length question) 2)))

(defun facts-located-in (agent container)
  (remove-if-not
   (lambda (belief)
     (let ((fact (belief-fact belief)))
       (and (symbol-name= (fact-predicate fact) 'location)
            (term= (fact-object fact) container))))
   (agent-beliefs agent)))

(defun contents-question-resolved-p (agent container)
  (and (not (member `(contents ,container) (agent-unknowns agent) :test #'term=))
       (or (why agent `(open ,container))
           (facts-located-in agent container))))

(defun contents-proposition-confirmed-p (agent container proposition)
  (and (consp proposition)
       (symbol-name= (fact-predicate proposition) 'contents)
       (term= (fact-subject proposition) container)
       (= (length proposition) 3)
       (let ((content (fact-object proposition)))
         (cond
           ((symbol-name= content 'empty)
            (and (contents-question-resolved-p agent container)
                 (null (facts-located-in agent container))))
           ((symbol-name= content 'unknown)
            nil)
           (t
            (why agent `(location ,content ,container)))))))

(defun refresh-hypothesis-status (agent hypothesis)
  (when (eql (hypothesis-status hypothesis) :active)
    (let ((question (hypothesis-question hypothesis)))
      (cond
        ((contents-question-p question)
         (let ((container (fact-subject question)))
           (cond
             ((contents-proposition-confirmed-p
               agent container (hypothesis-proposition hypothesis))
              (incf (agent-clock agent))
              (setf (hypothesis-status hypothesis) :confirmed
                    (hypothesis-resolved-at hypothesis) (agent-clock agent)))
             ((contents-question-resolved-p agent container)
              (incf (agent-clock agent))
              (setf (hypothesis-status hypothesis) :rejected
                    (hypothesis-resolved-at hypothesis) (agent-clock agent))))))
        ((why agent (hypothesis-proposition hypothesis))
         (incf (agent-clock agent))
         (setf (hypothesis-status hypothesis) :confirmed
               (hypothesis-resolved-at hypothesis) (agent-clock agent))))))
  hypothesis)

(defun update-hypotheses (agent)
  "Refresh active hypotheses against AGENT's current beliefs."
  (dolist (hypothesis (agent-hypotheses agent))
    (refresh-hypothesis-status agent hypothesis))
  (agent-hypotheses agent))

(defun active-hypotheses-for (agent question)
  (remove-if-not
   (lambda (hypothesis)
     (and (eql (hypothesis-status hypothesis) :active)
          (term= (hypothesis-question hypothesis) question)))
   (agent-hypotheses agent)))

(defun competing-hypotheses-p (agent question)
  (> (length (active-hypotheses-for agent question)) 1))

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
  (let ((before (belief-facts agent)))
    (cond
      ((fact-present-p world `(room ,target))
       (observe-room agent world target))
      (t
       (error "Don't know how to observe ~S yet." target)))
    (record-episode agent
                    :observation
                    `(observe ,target)
                    (new-facts-since agent before))
    agent))

(defun container-accessible-p (agent container)
  "Return true when AGENT already believes CONTAINER is visible."
  (why agent `(visible ,container)))

(defun observable-contained-properties-for (world thing)
  "Return facts learned when a container exposes THING."
  (remove-if-not
   (lambda (fact)
     (and (term= (fact-subject fact) thing)
          (member (fact-predicate fact)
                  '(object container color shape size location)
                  :test #'symbol-name=)))
   (world-facts world)))

(defun open-container (agent world container)
  "Open CONTAINER and let AGENT observe its immediate contents.

This is an action boundary: the world changes, but the agent only learns the
facts this action makes observable."
  (let ((before (belief-facts agent)))
    (unless (why agent `(container ,container))
      (error "The agent does not know that ~S is a container." container))
    (unless (container-accessible-p agent container)
      (error "The agent cannot access ~S." container))
    (unless (fact-present-p world `(closed ,container))
      (error "~S is not closed." container))
    (remove-world-fact world `(closed ,container))
    (add-world-fact world `(open ,container))
    (add-belief agent `(open ,container) :source :action-observation)
    (dolist (thing (things-located-in world container))
      (dolist (fact (observable-contained-properties-for world thing))
        (add-belief agent fact :source :action-observation))
      (when (fact-present-p world `(closed ,thing))
        (add-unknown agent `(contents ,thing))))
    (remove-unknown agent `(contents ,container))
    (update-hypotheses agent)
    (record-episode agent
                    :action
                    `(open-container ,container)
                    (new-facts-since agent before)))
  agent)

(defun suggest-action-for-unknown (agent unknown)
  (cond
    ((and (symbol-name= (fact-predicate unknown) 'contents)
          (fact-subject unknown))
     (let ((container (fact-subject unknown)))
       (when (and (why agent `(container ,container))
                  (container-accessible-p agent container)
                  (why agent `(closed ,container)))
         (make-action-suggestion
          :action 'open-container
          :target container
          :reason unknown
          :preconditions `((container ,container)
                           (visible ,container)
                           (closed ,container))
          :serves-goal (find `(known ,unknown)
                             (agent-goals agent)
                             :key #'goal-desire
                             :test #'term=)
          :tests-question (when (competing-hypotheses-p agent unknown)
                            unknown)))))
    (t
     nil)))

(defun suggest-actions (agent)
  "Suggest actions that may reduce AGENT's explicit unknowns.

Suggestions are derived from the agent's beliefs and unknowns only. They do not
inspect the hidden world state and they do not execute anything."
  (remove nil
          (mapcar (lambda (unknown)
                    (suggest-action-for-unknown agent unknown))
                  (agent-unknowns agent))))

(defun suggest-tests (agent)
  "Suggest currently available actions that could distinguish hypotheses."
  (remove-if-not #'action-suggestion-tests-question
                 (suggest-actions agent)))

(defun action-suggestion-serves-active-goal-p (suggestion)
  (let ((goal (action-suggestion-serves-goal suggestion)))
    (and goal
         (eql (goal-status goal) :active))))

(defun action-suggestion-tests-hypotheses-p (suggestion)
  (not (null (action-suggestion-tests-question suggestion))))

(defun select-action (agent)
  "Select one currently available action suggestion.

This is one-step action selection, not planning. Suggestions serving active
goals are preferred over curiosity-only suggestions."
  (let ((suggestions (suggest-actions agent)))
    (when suggestions
      (let ((goal-and-test
              (find-if (lambda (suggestion)
                         (and (action-suggestion-serves-active-goal-p suggestion)
                              (action-suggestion-tests-hypotheses-p suggestion)))
                       suggestions))
            (goal-suggestion (find-if #'action-suggestion-serves-active-goal-p
                                      suggestions))
            (test-suggestion (find-if #'action-suggestion-tests-hypotheses-p
                                      suggestions)))
        (cond
          (goal-and-test
           (make-selected-action
            :suggestion goal-and-test
            :reason :serves-active-goal-and-tests-hypotheses))
          (goal-suggestion
           (make-selected-action
            :suggestion goal-suggestion
            :reason :serves-active-goal))
          (test-suggestion
           (make-selected-action
            :suggestion test-suggestion
            :reason :tests-hypotheses))
          (t
           (make-selected-action
            :suggestion (first suggestions)
            :reason :reduces-unknown)))))))

(defun perform-suggestion (agent world suggestion)
  "Perform SUGGESTION in WORLD.

Only known action types are executable. This intentionally does not choose an
action or run an autonomous loop."
  (case (action-suggestion-action suggestion)
    (open-container
     (open-container agent world (action-suggestion-target suggestion)))
    (t
     (error "Don't know how to perform action ~S."
            (action-suggestion-action suggestion)))))

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

(defun why-retracted (agent fact)
  "Return the retraction record explaining why FACT is no longer active, or NIL."
  (find fact (agent-retractions agent) :key #'retraction-fact :test #'fact=))

(defun explain (agent fact)
  "Return an inspectable explanation for FACT.

The explanation distinguishes active beliefs, retracted beliefs, and facts the
agent has no explanation for."
  (let ((belief (why agent fact)))
    (cond
      (belief
       (make-explanation
        :fact (belief-fact belief)
        :status :believed
        :source (belief-source belief)
        :confidence (belief-confidence belief)
        :rule (belief-rule belief)
        :premises (mapcar (lambda (premise)
                            (explain agent premise))
                          (belief-premises belief))))
      ((why-retracted agent fact)
       (make-explanation
        :fact fact
        :status :retracted
        :retraction (why-retracted agent fact)))
      (t
       (make-explanation
        :fact fact
        :status :unknown)))))

(defun show-explanation (agent fact &optional (stream *standard-output*))
  "Print a readable explanation for FACT."
  (labels ((show (explanation depth)
             (let ((indent (make-string (* depth 2) :initial-element #\Space)))
               (format stream "~&~ABELIEF: ~S~%" indent (explanation-fact explanation))
               (format stream "~ASTATUS: ~S~%" indent (explanation-status explanation))
               (case (explanation-status explanation)
                 (:believed
                  (format stream "~ASOURCE: ~S~%" indent (explanation-source explanation))
                  (format stream "~ACONFIDENCE: ~S~%" indent
                          (explanation-confidence explanation))
                  (when (explanation-rule explanation)
                    (format stream "~ARULE: ~S~%" indent
                            (explanation-rule explanation)))
                  (when (explanation-premises explanation)
                    (format stream "~APREMISES:~%" indent)
                    (dolist (premise (explanation-premises explanation))
                      (show premise (1+ depth)))))
                 (:retracted
                  (let ((retraction (explanation-retraction explanation)))
                    (format stream "~AREASON: ~S~%" indent
                            (retraction-reason retraction))
                    (format stream "~AREPLACED-BY: ~S~%" indent
                            (retraction-replaced-by retraction))
                    (format stream "~ARETRACTED-AT: ~S~%" indent
                            (retraction-retracted-at retraction))))))))
    (show (explain agent fact) 0))
  (values))

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

(defun show-goals (agent &optional (stream *standard-output*))
  "Print AGENT's explicit goals."
  (format stream "~&GOALS:~%")
  (dolist (goal (sorted-copy (agent-goals agent) #'goal-desire))
    (format stream "  ~S ~S~%" (goal-status goal) (goal-desire goal)))
  (values))

(defun show-episodes (agent &optional (stream *standard-output*))
  "Print AGENT's episodic memory."
  (format stream "~&EPISODES:~%")
  (dolist (episode (reverse (agent-episodes agent)))
    (format stream "  ~S ~S -> ~S~%"
            (episode-type episode)
            (episode-detail episode)
            (episode-results episode)))
  (values))

(defun show-hypotheses (agent &optional (stream *standard-output*))
  "Print AGENT's explicit hypotheses."
  (format stream "~&HYPOTHESES:~%")
  (dolist (hypothesis (reverse (agent-hypotheses agent)))
    (format stream "  ~S ~S ~S ~S~%"
            (hypothesis-question hypothesis)
            (hypothesis-status hypothesis)
            (hypothesis-confidence hypothesis)
            (hypothesis-proposition hypothesis)))
  (values))

(defun show-memory (agent &optional (stream *standard-output*))
  "Print AGENT's current memory organized by conceptual role.

This is an architectural view over the current data structures, not a separate
memory store."
  (format stream "~&WORKING MEMORY:~%")
  (format stream "  GOALS:~%")
  (dolist (goal (sorted-copy (remove-if-not
                              (lambda (goal)
                                (eql (goal-status goal) :active))
                              (agent-goals agent))
                             #'goal-desire))
    (format stream "    ~S~%" (goal-desire goal)))
  (format stream "  UNKNOWNS:~%")
  (dolist (unknown (sorted-copy (agent-unknowns agent) #'identity))
    (format stream "    ~S~%" unknown))
  (format stream "  ACTIVE HYPOTHESES:~%")
  (dolist (hypothesis (reverse (remove-if-not
                                (lambda (hypothesis)
                                  (eql (hypothesis-status hypothesis) :active))
                                (agent-hypotheses agent))))
    (format stream "    ~S ~S ~S~%"
            (hypothesis-question hypothesis)
            (hypothesis-confidence hypothesis)
            (hypothesis-proposition hypothesis)))

  (format stream "~&SEMANTIC MEMORY:~%")
  (dolist (belief (sorted-copy (agent-beliefs agent) #'belief-fact))
    (format stream "  ~S~%" (belief-fact belief)))

  (format stream "~&EPISODIC MEMORY:~%")
  (dolist (episode (reverse (agent-episodes agent)))
    (format stream "  ~S ~S -> ~S~%"
            (episode-type episode)
            (episode-detail episode)
            (episode-results episode)))

  (format stream "~&REVISION HISTORY:~%")
  (format stream "  RETRACTIONS:~%")
  (dolist (retraction (reverse (agent-retractions agent)))
    (format stream "    ~S -> ~S (~S)~%"
            (retraction-fact retraction)
            (retraction-replaced-by retraction)
            (retraction-reason retraction)))
  (format stream "  RESOLVED HYPOTHESES:~%")
  (dolist (hypothesis (reverse (remove-if
                                (lambda (hypothesis)
                                  (eql (hypothesis-status hypothesis) :active))
                                (agent-hypotheses agent))))
    (format stream "    ~S ~S ~S~%"
            (hypothesis-status hypothesis)
            (hypothesis-question hypothesis)
            (hypothesis-proposition hypothesis)))
  (values))
