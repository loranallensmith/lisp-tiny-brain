(defpackage #:tiny-brain
  (:use #:cl)
  (:export
   #:make-world
   #:make-agent
   #:observe
   #:show-beliefs
   #:why
   #:agent-beliefs
   #:agent-unknowns
   #:belief
   #:belief-fact
   #:belief-confidence
   #:belief-source
   #:belief-observed-at))

