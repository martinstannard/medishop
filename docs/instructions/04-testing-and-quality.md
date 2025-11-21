# 4. Testing and Quality (Elixir/Phoenix/Ash)

Testing is a critical part of the Elixir development process. You are responsible for ensuring that your code is of high quality and is well-tested.

## 4.1. Write Tests with ExUnit

All tests in Elixir are written using the built-in `ExUnit` framework. For any new code you write, you must also write tests. The type of test you write will depend on the nature of the change:

*   **Unit tests:** Test individual functions or modules in isolation. In Phoenix, these might be tests for functions in your contexts. For Ash, you can test custom changes, calculations, and authorizers directly.
*   **Integration tests:** Test how different parts of the system work together. For Ash, this involves using Ash's testing helpers (`Ash.Test` module) to create records and perform actions on your resources.
*   **End-to-end / Request tests:** Test the entire system from the user's perspective. For Phoenix, this means writing `ConnTests` for controllers/GraphQL endpoints or `LiveViewTests` for LiveView interactions.

When fixing a bug, first write a failing test that reproduces the bug. Then, make the test pass by fixing the bug.

## 4.2. Run Existing Tests

Before you submit your work, run the full test suite to ensure that you have not introduced any regressions.

```bash
mix test
```

## 4.3. Code Formatting

All Elixir code should be formatted using the official formatter. This ensures a consistent style across the entire codebase.

```bash
mix format
```

## 4.4. Static Analysis and Linting

Before committing any code, run the following static analysis tools to catch potential issues:

*   **Credo:** A static analysis tool focused on code consistency and teaching best practices. Run it with `mix credo --strict`.
*   **Dialyzer:** A static analysis tool that identifies type inconsistencies, unreachable code, and other potential bugs. Run it with `mix dialyzer`.

Adhere to the project's established rules to maintain code consistency.

## 4.5. Test-Driven Development (TDD)

When implementing new features, adopt a Test-Driven Development (TDD) approach where appropriate:
1.  **Write a failing test:** Before writing any implementation code, create a new test that calls the desired functionality and asserts its expected outcome. This test should fail initially because the functionality does not yet exist.
2.  **Write the implementation:** Write the minimum amount of code required to make the failing test pass.
3.  **Refactor:** With the test passing, refactor the implementation code to improve its structure and readability.

This methodology ensures that your code is testable by design and that every feature is backed by a corresponding test.

## 4.6. Code Coverage

Ensure that your tests adequately cover the code you have written. Use `mix test --cover` to generate a coverage report. While 100% coverage is not always the goal, strive for a high level of coverage and ensure that all critical paths and edge cases are tested.

## 4.7. Refactoring

If you see an opportunity to improve the existing code, you are encouraged to do so. However, you should not mix refactoring with other changes.

If you want to refactor, create a separate step in your plan and a separate commit for the refactoring.
