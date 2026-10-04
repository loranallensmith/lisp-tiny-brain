# Project: A Tiny Artificial Mind

I want to build an experimental artificial-intelligence system that deliberately does **not** use a large language model, transformer, embeddings, or generative neural network as its primary mechanism.

This is an educational and philosophical experiment rather than an attempt to build a commercially useful AI system.

The central question is:

> What might a small, comprehensible artificial intelligence look like if we treated intelligence primarily as maintaining and reasoning over an explicit model of the world rather than predicting the next token?

I want to explore ideas from classical symbolic AI, Lisp, cognitive architectures, logic programming, probabilistic reasoning, planning, and eventually perhaps program synthesis.

## Important design philosophy

Keep this project **small, inspectable, and understandable by one person**.

Do not build an elaborate framework.

Do not introduce databases, web services, vector stores, embeddings, LLM APIs, neural networks, or large dependencies unless we explicitly decide later that an experiment requires one.

Prefer simple Lisp data structures and functions that we can inspect in a REPL.

I understand Lisp syntax and basic programming concepts, but I am not an expert Lisp programmer. Please favor readable, idiomatic code over clever Lisp tricks, and explain unfamiliar constructs when you introduce them.

The purpose is as much to understand the architecture as to make it work.

## Initial architecture

I want the system eventually to contain several conceptual components:

1. **World Model**

   An explicit representation of things the system currently believes about its environment.

   For example:

   ```lisp
   (object ball-1)
   (color ball-1 red)
   (location ball-1 box-2)
   ```

   Facts should eventually be capable of carrying metadata such as confidence, provenance, and when they were learned.

2. **Memory**

   We should eventually distinguish among things resembling:

   - working memory
   - semantic knowledge
   - episodic memories
   - learned procedures

   Do not implement all of this immediately. I want the architecture to evolve experimentally.

3. **Inference**

   The machine should be able to derive new beliefs from existing beliefs and explicit rules.

   Conceptually:

   ```lisp
   (rule
     (if (and (parent ?x ?y)
              (parent ?y ?z))
         (grandparent ?x ?z)))
   ```

   I am not committed to this exact syntax.

4. **Uncertainty**

   Eventually, beliefs should not necessarily be simply true or false.

   The machine should be able to represent something like:

   ```text
   hypothesis A: 0.70
   hypothesis B: 0.20
   unknown:      0.10
   ```

   The important point is that uncertainty should be explicit and inspectable rather than hidden inside millions of learned parameters.

5. **Goals and Planning**

   Eventually the machine should be able to represent desired states and reason backward or forward about actions that could produce them.

6. **Curiosity / Information Seeking**

   Eventually I want the machine to recognize uncertainty and ask:

   > What observation could I make that would best distinguish between my competing hypotheses?

   This is an important part of the experiment.

7. **Learning**

   Ultimately I would like to investigate whether the system can learn new rules, concepts, procedures, or small programs from experience.

   Program synthesis, inductive logic programming, genetic programming, Bayesian approaches, and Minimum Description Length may eventually be interesting avenues.

   But **do not implement these yet**.

## A critical constraint

Do not simulate intelligence by writing a giant collection of handcrafted domain-specific rules.

I want to distinguish between:

> "The programmer encoded the answer."

and:

> "The system derived or learned the answer."

We should continually ask which of those is happening.

Likewise, don't quietly replace difficult pieces of the architecture with calls to an LLM. The whole point is to see how far we can get without one.

## First experiment

For version 0.1, let's create an extremely small artificial world.

For example, the world might contain:

- several rooms
- several objects
- object properties such as color, shape, and size
- containers
- locations
- a small number of possible actions

The agent should initially know only part of the world's state.

The environment itself should maintain the actual ground truth separately from what the agent believes.

This distinction is important:

```text
REAL WORLD STATE
        ↓
 observations
        ↓
AGENT'S WORLD MODEL
```

The agent should **never be allowed to inspect ground truth directly**.

It should only learn about the world through observations.

That gives us a controlled environment in which beliefs can be correct, incorrect, incomplete, or uncertain.

## Version 0.1 milestone

Let's keep the first milestone extremely modest.

I want to be able to launch a Lisp REPL and do something conceptually like:

```lisp
(make-world)
(make-agent)

(observe agent world 'room-1)

(show-beliefs agent)
```

and see something like:

```text
KNOWN:
  (room room-1)
  (object ball-1)
  (color ball-1 red)
  (location ball-1 room-1)

UNKNOWN:
  contents of box-1
```

Then perhaps:

```lisp
(why agent '(color ball-1 red))
```

could eventually return:

```text
BELIEF:
  (color ball-1 red)

SOURCE:
  direct observation

CONFIDENCE:
  1.0
```

The first version does **not** need natural-language interaction.

In fact, I would prefer that it not have natural-language interaction yet. I want to interact directly with its internal representations so that we don't mistake linguistic fluency for intelligence.

## Development approach

Please work incrementally.

Before writing substantial code:

1. Recommend an appropriate Common Lisp implementation and minimal project structure.
2. Explain your proposed representation for facts, entities, beliefs, and world state.
3. Identify the smallest useful version we can build.
4. Tell me what you're deliberately leaving out.
5. Then scaffold the project.

Create a README that explains the architecture in plain English and maintain it as the architecture evolves.

I'd also like automated tests, but keep the testing infrastructure simple.

Most importantly, treat me as a collaborator conducting an experiment rather than a customer requesting a finished application.

When we encounter an architectural decision, prefer exposing the interesting decision to me rather than silently making the system more sophisticated.

## Guiding questions

Throughout development, keep returning to these questions:

- What does the machine actually know?
- How is that knowledge represented?
- How did it acquire that knowledge?
- What can it infer that it was never explicitly told?
- How does it distinguish knowledge from belief?
- How does it represent uncertainty?
- Can it explain why it believes something?
- Can it recognize what it doesn't know?
- Can it identify an observation that would reduce its uncertainty?
- Can it learn something genuinely new rather than merely retrieve something we programmed into it?
- How much computation and memory does each capability require?

The eventual goal is not to reproduce GPT badly.

The goal is to explore a different hypothesis about artificial intelligence:

> **Intelligence may be the process by which an agent builds, tests, revises, and acts upon increasingly useful models of its world.**

Let's start with the smallest possible system capable of testing that idea.