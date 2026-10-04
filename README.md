# A Tiny Artificial Mind

This is an experiment in building a small, inspectable AI system without using
LLMs, embeddings, transformers, neural networks, or a large hidden framework.

The current goal is modest: create a tiny artificial world with hidden ground
truth, give an agent partial observations, infer a few simple consequences,
perform one small action, suggest actions that could reduce uncertainty, and
represent simple goals while inspecting how the agent updates its beliefs and
remembers what happened.

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
examples/*.lisp         Editable scenario files
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

## Scenarios

Version 0.14 starts moving the project from a single hardcoded demo toward an
inspectable agent workbench. A scenario is plain Lisp data:

```lisp
(define-scenario kitchen-box
  :facts ((room kitchen)
          (container cabinet)
          (closed cabinet)
          (location cabinet kitchen)
          (object mug)
          (location mug cabinet))
  :observations (kitchen)
  :goals ((known (contents cabinet))))
```

Load and start one with:

```lisp
(defparameter *scenario* (load-scenario "examples/kitchen-box.lisp"))
(multiple-value-bind (agent world) (start-scenario *scenario*)
  (declare (ignore world))
  (show-memory agent))
```

`start-scenario` still respects the observation boundary: it creates a hidden
world from the facts, lets the agent observe only the listed targets, runs
inference by default, then records the scenario's goals and hypotheses.

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

## Goals

Version 0.7 adds explicit goals:

```lisp
(add-goal *agent* '(known (contents box-1)))
(show-goals *agent*)
```

A goal is not a plan. It is an inspectable desired state with a status:

```lisp
(goal
  :desire '(known (contents box-1))
  :status :active
  :created-at 12
  :satisfied-at nil)
```

For now, goal satisfaction is deliberately narrow:

- `(known FACT)` is satisfied when the agent believes `FACT`.
- `(known (contents CONTAINER))` is satisfied when the explicit contents
  unknown has been resolved by opening the container.

Action suggestions can point at a goal they serve, but they still do not execute
automatically and they do not search for multi-step plans.

## One-Step Action Selection

Version 0.8 adds a tiny action-selection layer:

```lisp
(select-action *agent*)
(perform-suggestion *agent* *world* suggestion)
```

Selection returns an inspectable `selected-action` record. Suggestions that
serve active goals are preferred over curiosity-only suggestions.

This is not planning. It does not search, loop, or invent new actions. It only
chooses one currently available suggestion and can execute known action types,
starting with `open-container`.

## One-Step Plans

Version 0.13 adds tiny inspectable plans:

```lisp
(defparameter *plan* (plan-for-goal *agent* '(known (contents box-1))))
(show-plan *plan*)
```

A plan answers "what sequence could satisfy this goal?" while `select-action`
answers "what should I do now?" For now, the sequence is intentionally limited
to one currently available suggestion:

```lisp
(plan
  :goal '(known (contents box-1))
  :steps (list suggestion)
  :status :ready
  :reason :one-step-suggestion)
```

Plan statuses are:

- `:satisfied` when the desired state is already true for the agent
- `:ready` when one available action suggestion can make progress
- `:blocked` when no current suggestion can serve the goal

This is still not recursive search. Plans expose the next available step
without inventing hidden state or running an autonomous loop.

## Step Traces

Version 0.15 adds a controlled step runner:

```lisp
(defparameter *trace* (step-agent *agent* *world*))
(show-trace *trace*)
```

One step refreshes inference, plans for the current active goal, executes one
ready action when available, refreshes inference again, and returns a
`step-trace` describing what changed:

```lisp
(step-trace
  :status :acted
  :goal '(known (contents cabinet))
  :action '(open-container cabinet)
  :new-beliefs '((open cabinet) ...)
  :resolved-unknowns '((contents cabinet)))
```

This is the beginning of a usable scenario runner. It is still deliberately
bounded: one call, one inspectable step, no hidden autonomous loop.

## Episodic Memory

Version 0.9 adds a small episodic memory:

```lisp
(agent-episodes *agent*)
(show-episodes *agent*)
```

Episodes record observations and actions:

```lisp
(episode
  :type :observation
  :detail '(observe room-1)
  :results '((room room-1) ...)
  :time 13)
```

Current beliefs are still the agent's semantic-ish model of what is true now.
Episodes are a history of what happened. For now, inference does not create
episodes, and episodes are not used for reasoning.

## Hypotheses

Version 0.10 adds explicit competing hypotheses:

```lisp
(add-hypothesis *agent*
                '(contents box-1)
                '(contents box-1 key-1)
                0.70)

(show-hypotheses *agent*)
```

A hypothesis is not a belief. It records a proposition, confidence, source, and
status under a question such as `(contents box-1)`.

For now, confidence values are assigned manually. There is no Bayesian update
yet. When later observations settle a contents question, compatible hypotheses
are marked `:confirmed` and incompatible ones are marked `:rejected`.

## Hypothesis Testing

Version 0.11 lets the agent notice when an available action could distinguish
active competing hypotheses:

```lisp
(suggest-tests *agent*)
```

For example, if there are multiple active hypotheses for `(contents box-1)`,
then opening `box-1` can be marked as testing that question. Action selection
now prefers suggestions that both serve an active goal and test hypotheses, then
goal-serving suggestions, then hypothesis tests, then curiosity-only unknown
reduction.

This is symbolic information seeking, not entropy or expected-value math yet.

## Memory View

Version 0.12 adds an architectural memory view:

```lisp
(show-memory *agent*)
```

This does not introduce a new storage engine. It groups the agent's existing
state by conceptual role:

- working memory: active goals, unknowns, and active hypotheses
- semantic memory: current beliefs
- episodic memory: observations and actions
- revision history: retractions and resolved hypotheses

The point is to make the memory architecture inspectable before making it more
sophisticated.

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
(add-goal *agent* '(known (contents box-1)))
(add-hypothesis *agent* '(contents box-1) '(contents box-1 key-1) 0.70)
(add-hypothesis *agent* '(contents box-1) '(contents box-1 empty) 0.20)
(add-hypothesis *agent* '(contents box-1) '(contents box-1 unknown) 0.10)
(suggest-tests *agent*)
(defparameter *plan* (plan-for-goal *agent* '(known (contents box-1))))
(show-plan *plan*)
(defparameter *trace* (step-agent *agent* *world*))
(show-trace *trace*)
(show-beliefs *agent*)
(show-goals *agent*)
(show-episodes *agent*)
(show-hypotheses *agent*)
(show-memory *agent*)

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
- planning or multi-step action search
- learned procedures
- probabilistic updates, entropy, or normalized hypothesis sets
- a general truth-maintenance system
- reasoning over episodic memory
- separate memory stores beyond the current grouped view
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
