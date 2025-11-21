# 3. Development Workflow

Follow a structured development workflow to ensure that your work is of high quality and easy to review.

## 3.1. Break Down Work into Commits

Each step in your plan should correspond to a single commit. A commit should be a small, logical change that is easy to understand and review.

**A good commit:**

*   **Is small and focused.** It should do one thing and do it well.
*   **Has a clear and concise commit message.** The message should explain the "what" and the "why" of the change.
*   **Is self-contained.** It should not depend on other, uncommitted changes.

**Commit Message Format:**

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Example Commit Message:**

```
feat(api): add GetUserProfile endpoint

Adds a new endpoint to retrieve a user's profile information.

This endpoint will be used by the frontend to display the user's profile
page.
```

## 3.2. One Change at a Time

Work on one change at a time. Do not mix unrelated changes in the same commit. This makes it difficult to review your work and can introduce bugs.

## 3.3. Automate Quality Checks with Pre-Commit Hooks

To ensure that all code entering the repository meets quality standards, use pre-commit hooks. These are automated scripts that run before a commit is created.

Configure pre-commit hooks to run Elixir-specific commands:
*   **Run formatter:** Ensure consistent code style with `mix format --check-formatted`.
*   **Run linter/static analysis:** Catch common issues with `mix credo --strict` and `mix dialyzer`.
*   **Execute unit tests:** Run relevant unit tests with `mix test --listen-on-stdin` to ensure that your changes have not broken existing functionality.

By automating these checks, you prevent common errors and maintain a high-quality codebase.

## 3.4. Keep the User Informed

Keep the user informed of your progress.

*   When you start a new step, let the user know.
*   When you complete a step, let the user know.
*   If you get stuck, let the user know.
