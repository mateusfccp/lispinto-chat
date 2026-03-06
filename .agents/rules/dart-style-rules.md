---
trigger: always_on
---

# Prefer literal collections

Whenever possible, use literal collections instead of method.

For instance, instead of `.where` and `.map`, use literal collections with `if` and `for`.

# When to use fat-arrow?

Only use fat-arrow if the function is a single expression and it fits before the 80 characters limit.

If it spans over the 80 characters limit, making it break down to the next line, use block function with `return` instead.

# About early returns

Only use early-returns when the following code is extensive and would case an undesired nesting.

In general, prefer if-else to many successive if-return.