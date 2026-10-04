# A Tiny Artificial Mind

This is an experiment in building a small, inspectable AI system without using
LLMs, embeddings, transformers, neural networks, or a large hidden framework.

The current goal is modest: create a tiny artificial world with hidden ground
truth, give an agent partial observations, and inspect what the agent believes.

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
  :observed-at 1)
```

Unknowns are represented explicitly as small records like:

```lisp
(contents box-1)
```

For now, confidence is present but boring: direct observations have confidence
`1.0`. This gives us a slot to evolve later without pretending we have solved
uncertainty.

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
(show-beliefs *agent*)

(why *agent* '(color ball-1 red))
```

Expected shape:

```text
KNOWN:
  (ROOM ROOM-1)
  (OBJECT BALL-1)
  (COLOR BALL-1 RED)
  (LOCATION BALL-1 ROOM-1)
  ...

UNKNOWN:
  (CONTENTS BOX-1)
```

## What Is Deliberately Left Out

This first milestone does not include:

- natural-language interaction
- a rule engine
- planning
- learned procedures
- probabilistic updates
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
