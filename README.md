# A Tiny Artificial Mind

This is an experiment in building a small, inspectable AI system without using
LLMs, embeddings, transformers, neural networks, or a large hidden framework.

The current goal is modest: create a tiny artificial world with hidden ground
truth, give an agent partial observations, infer a few simple consequences,
perform one small action, suggest actions that could reduce uncertainty, and
inspect how the agent updates its beliefs.

## Recommended Lisp

Use **SBCL**. It is mature, fast, widely packaged, and includes ASDF, which is
enough for this project's simple system and test setup.

On many Linux systems:

```sh
sudo dnf install sbcl
```

or:

```sh
sudo apt install sbcl
```

## Project Shape

```text
lisp-tiny-brain.asd     ASDF system definition
src/package.lisp        Public package and exports
src/core.lisp           Tiny world, agent, beliefs, observations
tests/package.lisp      Test package
tests/core-tests.lisp   Minimal dependency-free test runner
tests/run-tests.lisp    Script entry point for tests
```

## Core Representation

The system starts with plain Lisp facts:

```lisp
(color ball-1 red)
(location ball-1 room-1)
```

A fact is just a list. This keeps the representation simple enough to inspect
directly in a REPL.

The real environment stores ground-truth facts internally. The agent does not
copy the whole world. It only accumulates `belief` records:

```lisp
(belief
  :fact '(color ball-1 red)
  :confidence 1.0
  :source :direct-observation
  :observed-at 1
  :rule nil
  :premises nil)
```

Unknowns are represented explicitly as small records like:

```lisp
(contents box-1)
```

For now, confidence is present but boring: direct observations have confidence
`1.0`. This gives us a slot to evolve later without pretending we have solved
uncertainty.

Inferred beliefs use the same record, but with `:source :inference`, a rule
name, and the premise facts that supported the conclusion.

## Inference

Version 0.2 adds a tiny forward-chaining inference pass:

```lisp
(infer *agent*)
```

Rules are explicit Lisp structures with:

- a name
- premise patterns
- a conclusion pattern

For example, the rule named `:thing-in-observed-room-is-visible` says:

```lisp
premises:   ((location ?thing ?room)
             (room ?room))
conclusion: (visible ?thing)
```

The inference engine only reads the agent's beliefs. It does not inspect the
world's hidden ground truth.

## Actions

Version 0.3 adds one action:

```lisp
(open-container *agent* *world* 'box-1)
```

Opening a known, accessible, closed container changes the real world from:

```lisp
(closed box-1)
```

to:

```lisp
(open box-1)
```

The agent does not receive arbitrary world access. It only learns facts made
observable by the action, such as the immediate contents of the opened
container. These beliefs use `:source :action-observation`.

For now, accessibility is intentionally simple: the agent must already believe
the container is visible. That means this works after:

```lisp
(observe *agent* *world* 'room-1)
(infer *agent*)
(open-container *agent* *world* 'box-1)
```

## Curiosity

Version 0.4 adds a tiny form of information seeking:

```lisp
(suggest-actions *agent*)
```

This does not execute anything and it is not a planner. It maps explicit
unknowns to actions that might resolve them, using only the agent's current
beliefs.

For example, if the agent has:

```lisp
(contents box-1)
```

and believes:

```lisp
(container box-1)
(visible box-1)
(closed box-1)
```

then it can suggest an inspectable record shaped like:

```lisp
(action-suggestion
  :action 'open-container
  :target 'box-1
  :reason '(contents box-1)
  :preconditions '((container box-1)
                   (visible box-1)
                   (closed box-1)))
```

## Belief Revision

Version 0.5 adds a tiny belief-maintenance mechanism for mutually exclusive
state predicates.

For now, the only exclusive group is:

```lisp
(open closed)
```

That means adding:

```lisp
(open box-1)
```

automatically retracts:

```lisp
(closed box-1)
```

The retraction is recorded on the agent:

```lisp
(agent-retractions *agent*)
```

Each retraction records the old fact, the reason, the replacing fact, and when
the retraction happened. This is deliberately small: it handles simple unary
state replacement, not full contradiction detection or truth maintenance.

## Explanation

Version 0.6 adds a structured explanation layer:

```lisp
(explain *agent* '(visible ball-1))
(show-explanation *agent* '(visible ball-1))
```

`why` still returns the raw belief record for an active belief. `explain`
returns a higher-level explanation object that can distinguish:

- active beliefs
- inferred beliefs with premise explanations
- retracted beliefs
- unknown facts

For example, an inferred belief records its rule and recursively explains the
premises that supported it. A retracted belief points at the retraction record
that says what replaced it.

## What Version 0.1 Can Do

Start a REPL from this directory:

```sh
sbcl --load lisp-tiny-brain.asd
```

Then:

```lisp
(asdf:load-system :lisp-tiny-brain)
(in-package :tiny-brain)

(defparameter *world* (make-world))
(defparameter *agent* (make-agent))

(observe *agent* *world* 'room-1)
(infer *agent*)
(suggest-actions *agent*)
(open-container *agent* *world* 'box-1)
(infer *agent*)
(show-beliefs *agent*)

(why *agent* '(color ball-1 red))
(why *agent* '(visible ball-1))
(why *agent* '(object key-1))
(show-explanation *agent* '(location key-1 room-1))
(show-explanation *agent* '(closed box-1))
```

Expected shape:

```text
KNOWN:
  (ROOM ROOM-1)
  (OBJECT BALL-1)
  (COLOR BALL-1 RED)
  (LOCATION BALL-1 ROOM-1)
  (OBJECT KEY-1)
  (OPEN BOX-1)
  (VISIBLE BALL-1)
  ...

UNKNOWN:
  ;; empty after box-1 has been opened
```

## What Is Deliberately Left Out

This first milestone does not include:

- natural-language interaction
- a general-purpose rule engine
- planning or multi-step action selection
- learned procedures
- probabilistic updates
- a general truth-maintenance system
- a database
- external services
- neural networks, embeddings, or LLM calls

Those omissions are the point. The first useful thing is a clear boundary
between reality and belief.

## Guiding Questions

When changing the system, keep asking:

- What does the machine actually know?
- How did it acquire that knowledge?
- Is this ground truth, belief, or uncertainty?
- Could the agent explain why it believes this?
- Are we deriving something, or did the programmer encode the answer?

## Running Tests

```sh
sbcl --script tests/run-tests.lisp
```
