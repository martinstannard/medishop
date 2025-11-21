# 2. Planning and Documentation

Once you have a clear understanding of the task, you must create a comprehensive plan and document it. This plan will serve as your guide and will help the user understand your approach.

## 2.1. Create a Plan

Your plan should include:

*   **A high-level summary of your approach.** This should explain how you intend to solve the problem.
*   **A breakdown of the work into small, manageable steps.** Each step should be a single, logical change.
*   **An estimate of the effort required for each step.** This will help the user track your progress.
*   **Any potential risks or dependencies.** This will help the user understand the potential challenges.

## 2.2. Document the Plan

Document your plan in a clear and concise way. Use markdown to format your plan and make it easy to read.

**Example Plan Structure:**

```markdown
### Plan

1.  **Refactor the `UserService` to use the new `Database` interface.**
    *   Effort: Small
    *   Dependencies: None
2.  **Add a new `GetUserProfile` endpoint to the `UserController`.**
    *   Effort: Medium
    *   Dependencies: `UserService` refactoring
3.  **Create a new `UserProfile` component in the frontend.**
    *   Effort: Medium
    *   Dependencies: `GetUserProfile` endpoint
4.  **Write unit tests for the `UserService` and `UserController`.**
    *   Effort: Small
    *   Dependencies: None
5.  **Write end-to-end tests for the user profile feature.**
    *   Effort: Medium
    *   Dependencies: `UserProfile` component
```

## 2.3. Update the Plan

Your plan is a living document. As you work, you may need to update it to reflect new information or changes in the requirements.

*   If you encounter an unexpected problem, update the plan to include a new step to address it.
*   If the user changes the requirements, update the plan to reflect the new requirements.
*   Keep the user informed of any changes to the plan.
