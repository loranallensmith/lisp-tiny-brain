(defpackage #:tiny-brain
  (:use #:cl)
  (:export
   #:make-world
   #:make-agent
   #:observe
   #:infer
   #:open-container
   #:show-beliefs
   #:why
   #:agent-beliefs
   #:agent-unknowns
   #:belief
   #:belief-fact
   #:belief-confidence
   #:belief-source
   #:belief-observed-at
   #:belief-rule
   #:belief-premises
   #:rule
   #:rule-name
   #:rule-premises
   #:rule-conclusion))
