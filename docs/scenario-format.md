# Scenario Format

Scenarios are small Lisp data files that describe a hidden world and the
agent's starting situation.

Run one with:

```sh
sbcl --script scripts/run-scenario.lisp examples/kitchen-box.lisp
```

Validate one without running it:

```sh
sbcl --script scripts/validate-scenario.lisp examples/kitchen-box.lisp
```

## Shape

Each file contains one `define-scenario` form:

```lisp
(define-scenario kitchen-box
  :facts ((room kitchen)
          (container cabinet)
          (closed cabinet)
          (location cabinet kitchen)
          (object mug)
          (location mug cabinet))
  :observations (kitchen)
  :goals ((known (contents cabinet)))
  :hypotheses (((contents cabinet)
                (contents cabinet mug)
                0.7)
               ((contents cabinet)
                (contents cabinet empty)
                0.3)))
```

## Facts

Facts are plain lists. The current runner understands these predicates best:

- `(room NAME)`
- `(object NAME)`
- `(container NAME)`
- `(closed CONTAINER)`
- `(color THING COLOR)`
- `(shape THING SHAPE)`
- `(size THING SIZE)`
- `(location THING PLACE)`

Rooms are observable targets. Objects and containers become visible when their
location is an observed room. Closed containers create an explicit unknown:

```lisp
(contents cabinet)
```

At scenario startup, the agent receives the room facts as a simple map. It does
not learn which objects are in unobserved rooms until it observes those rooms.
This allows scenarios such as `examples/blocked-goal.lisp`, where the agent
first observes a remote room and then opens the container it finds there.

## Observations

`:observations` lists rooms the agent observes at startup:

```lisp
:observations (kitchen)
```

Observation targets must be rooms declared in `:facts`.

## Goals

The most useful current goal is:

```lisp
(known (contents cabinet))
```

That goal is satisfied when the agent resolves the explicit contents unknown,
usually by opening the container.

## Hypotheses

Hypotheses let the agent track competing possibilities:

```lisp
((contents cabinet) (contents cabinet mug) 0.7)
((contents cabinet) (contents cabinet empty) 0.3)
```

Each hypothesis has a question, a proposition, and a confidence from `0` to
`1`. The proposition should answer the same question.

## Validation

Validation catches common authoring mistakes:

- observing a missing room
- marking a non-container as closed
- declaring a container without a location
- asking for contents of an undeclared container
- writing malformed hypotheses
- writing a hypothesis that answers a different question

Use `examples/invalid-scenario.lisp` to see validation output on purpose.

## Current Limits

This is still a tiny symbolic world. The action system currently knows how to
observe known rooms and open accessible closed containers. It does not yet
support pickup, search, arbitrary actions, or recursive planning.
